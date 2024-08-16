//+------------------------------------------------------------------+
//|                                           SmartInvestBasicV3.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"



#include "SmartInvestBasicParams.mqh"


/*
TODO
BUY ONLY/ SELL ONLY
Shutdown after close

*/
/*
FIXURI
2024.01.12  - Fix pentru lateStart si Multiplier
            - Fix pentru afisarea NextLot in Dashboard  (needsTesting)
2024.02.22  - Fix lot formula (removed "+1")


BUG cu calcularea distantei -> PriceCurrent vs Price open asta imi compara bid cu ask in loc sa compare bid cu bid si ask cu ask 399 -> DONE
BUG IsSessionTrade pe MQL4 -> trebuie fixata metoda ca facem spam la mql4

BUG/Upgrade la clasa cu new Candle ( si fac structuri sau clase cu lista de clase si sa verific symbolu structuri si sa fie obiecte diferite/creeate)
*/

/*
Sa am grija la DD to close
Cand calculez swapurile si comisioanele sa vad ca de fapt nu pun la socoteala swap/comision sau nu stiu exact cum face daca tre sa ma uit in history sau nu
swap cred ca ia dar comisionul il vede doar in history

*/


/*
Hedging streategies ideas
Incep complementarea direct sau de la a doua tranzactie de complementare VARIANTE:
-> deschis cu lot fix sau cu procent din intreaga valoare a secventei
-> inchid de fiecare data cand deschid un nou trade deci profitul e garantat daca stepul este destul de mare incat sa acopere swap/comision
-> cand se intoarce medierea fie inchid toata medierea si las tradeul de complemantare si vad ce  fac de acolo
-> fie inchid toata medierea luand in calcul si minusul generat de tranzactia de complementare ( aici tre sa vad exact cum iau volumele ca sa calculez SL/TP sau daca inchid fix cand e pe plus un anumit numar de puncte
   pot sa inchid si cand e profiul =0 sau cand plusulde pe mediere + minusul de pe complementare ajunge la numarul dorit de puncte castigate
      asta inseamnca ca am profit cu 1 lot 50p si minus cu 0.1 de exemplu 400 puncte acel 1 lot trebuie sa compenseze acel 0.1
-> din profituri pot sa si inchid din volumele existente de mediere de la un anumit punct inainte si sa reduc distanta pana la TP (inchid trade pe plus, inchid volume, modific TP)
*/


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSmartInvestV3 : public CExpertAdvisor
{

protected:
   STradesDetails    _sTradeDetails;

private:
   datetime          candleTime;
   ENUM_DIRECTION     _direction;
   CPositionInfo      _positionInfo;
   CTradeManager      _tradeManager;
   CHedgeBase*        hedge;

   int                _currentGap;
   CSmartInvestParams *_params;
public:
                    ~CSmartInvestV3()
   {
      SafeDelete(hedge);
   }
                     CSmartInvestV3(CSmartInvestParams* params): _params(params)
   {
      if(_params.IsHedge())
         hedge = new CHedgeCandles(_params.GetMagic(), _params.GetSymbol(), _params.GetHedgeDrawDownType(), _params.GetHedgeDrawDownToCloseValue());
      else
         hedge = NULL;

      /*
      if(!mIsHedge)
         hedge.HideAllButtons();
      if(!mIsHedge)
         hedge.RemoveLines();
      */

      _tradeManager.SetMagic(_params.GetMagic());
      _tradeManager.SetSymbol(_params.GetSymbol());

      CTradeUtils::CalculateTradesDetails(_sTradeDetails, _params.GetMagic(), _params.GetSymbol());
      _direction = GetCurrentDirection();

      candleTime = 0;
      CCandleInfo::IsNewCandle(candleTime, PERIOD_CURRENT, _params.GetSymbol());

      OnReInit();

      SetupMillisTimer(MSC_ON_TIMER);

#ifdef __MQL5__
      if(LAST_UNINIT_REASON == 0)
         PrintInputParams();
#endif
   }

   //Expert Advisor Specific
public:
   virtual void       Main();
   virtual void       OnTimer_();
   virtual void       OnChartEvent_(const int id, const long &lparam, const double &dparam, const string &sparam);
   virtual void       OnDeinit_(const int reason);
protected:
   virtual void       OnReInit();


   //SmartInvestSpecific
protected:
   virtual ENUM_DIRECTION     GetSignalFirstTrade();
   virtual ENUM_DIRECTION     GetSignalSubsequentTrades(ENUM_DIRECTION direction); //rename this into GetSignalNextTrade /Subsequent
   virtual ENUM_DIRECTION     GetCurrentDirection();

   virtual bool               OpenTrade(ENUM_DIRECTION direction);
   virtual bool               ModifyTrades(ENUM_DIRECTION direction);

   virtual bool               CheckDrawDownToClose();
   virtual double             GetDrawDown();
   virtual double             GetLots();
   virtual int                GetStep();

   virtual void               ManageTrades();
   virtual void               ManageDrawDown();
   virtual void               ManageDashboard();

   //DashBoardSettings
   virtual void               AddLineToDashboard(string& dashboard, string fieldName, string value);
   virtual void               DisplayExpertInfo();
   virtual void               PrintInputParams();

};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::Main()
{
   if(_params.IsHedge() && CMQLInfo::IsTesting_() && TimeCurrent() > lastOnTimerExecution + timeToWaitInTester)
   {
      //OnTimer(); //uncomment this
      lastOnTimerExecution =  TimeCurrent();
   }

   if(CSymbolInfo::GetSpread(_params.GetSymbol()) > _params.GetSpreadFilter())
      return;

   CTradeUtils::CalculateTradesDetails(_sTradeDetails, _params.GetMagic(), _params.GetSymbol());

   if(_sTradeDetails.totalPositions == 0 && _direction != ENUM_DIRECTION_NEUTRAL)
   {
      _direction = ENUM_DIRECTION_NEUTRAL;
   }

   ManageDrawDown();
   if(_params.IsHedge())
      if(hedge.IsActive())
         return;

   ManageTrades();
   ManageDashboard();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::ManageTrades()
{
   if(!CCandleInfo::IsNewCandle(candleTime, PERIOD_CURRENT, _params.GetSymbol()))
      return;
   bool tradeHasOpenedSuccessfully = false;

   if(_sTradeDetails.totalPositions == 0)
   {
      _direction = GetSignalFirstTrade();
      tradeHasOpenedSuccessfully = OpenTrade(_direction);
   }
   else if(_sTradeDetails.totalPositions <= _params.GetMaxTrades())
   {
      ENUM_DIRECTION signal = GetSignalSubsequentTrades(_direction);
      tradeHasOpenedSuccessfully = OpenTrade(signal);
   }

   if(tradeHasOpenedSuccessfully)
   {
      ModifyTrades(_direction);
      CTradeUtils::CalculateTradesDetails(_sTradeDetails, _params.GetMagic(), _params.GetSymbol());
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::ManageDrawDown()
{
   if(_params.IsHedge())
      hedge.Main(_sTradeDetails, _direction);

   if(_params.IsCloseAtDrawDown())
   {
      double runningProfit = GetDrawDown();
      if(runningProfit > _params.GetDrawDownToCloseValue())
         return;

      LOG_INFO(StringFormat("Closing all trades, drawdown on EA reached its value of %s, drawdown close type %s",
                            DoubleToString(runningProfit, 2),
                            EnumToString(_params.GetDrawDownType())
                           ));
      int type = CEnums::FromDirectionToMarketOrder(_direction);
      _tradeManager.CloseBatch(_params.GetMagic(), _params.GetSymbol(), type);
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::ManageDashboard()
{
   if(_params.IsDisplayInformaion())
      DisplayExpertInfo();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CSmartInvestV3::GetDrawDown()
{
   if(_params.GetDrawDownType() == ENUM_DRAWDOWN_PERCENTAGE)
   {
      return CRiskService::RunningProfitBalancePercent(_params.GetMagic(), _params.GetSymbol());
   }

   if(_params.GetDrawDownType() == ENUM_DRAWDOWN_CASH)
   {
      return CRiskService::RunningProfitCash(_params.GetMagic(), _params.GetSymbol());
   }

   return DBL_MAX;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION CSmartInvestV3::GetSignalFirstTrade()
{
   return CSymbolInfo::CandleTypeBullishOrBearish(PERIOD_CURRENT, _params.GetSymbol());
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION CSmartInvestV3::GetSignalSubsequentTrades(ENUM_DIRECTION direction)
{
   if(direction == ENUM_DIRECTION_NEUTRAL)
      return direction;

// Determine the positionTicket based on the direction
   long positionTicket = (_direction == ENUM_DIRECTION_BULLISH)
                         ? (long)_sTradeDetails.lowestLevelBuyPosTicket
                         : (long)_sTradeDetails.highestLevelSellPosTicket;

// If position selection by ticket fails, log error and return neutral direction
   if(!_positionInfo.SelectByTicket(positionTicket))
   {
      int errorCode = GetLastError();
      LOG_ERROR(StringFormat("Could not select position with ticket[%s] >> [%s]:[%s]",
                             IntegerToString(positionTicket),
                             IntegerToString(errorCode),
                             ErrorDescription(errorCode)));
      return ENUM_DIRECTION_NEUTRAL;
   }

// Calculate the distance between opening and current price points
   double priceOpen = _positionInfo.PriceOpen();
   double priceCurrent = CTradeUtils::StartPrice(_positionInfo.Symbol(), (int)_positionInfo.PositionType());


   int distance = CTradeUtils::DistanceBetweenTwoPricesPoints(
                     (_direction == ENUM_DIRECTION_BULLISH) ? priceOpen : priceCurrent,
                     (_direction == ENUM_DIRECTION_BULLISH) ? priceCurrent : priceOpen,
                     _positionInfo.Symbol()
                  );

   _currentGap = distance;

   int step = GetStep();
// Return direction based on the distance value
   return (distance < step) ? ENUM_DIRECTION_NEUTRAL : _direction;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSmartInvestV3::OpenTrade(ENUM_DIRECTION direction = ENUM_DIRECTION_NEUTRAL)
{
   if(direction == ENUM_DIRECTION_NEUTRAL)
      return false;

// Determine the number of lots to trade based on Martingale settings
   double lots = GetLots();

// Convert the direction into a market order type
   int orderType = CEnums::FromDirectionToMarketOrder(direction);
   if(orderType < 0)
      return false; // If conversion fails, return false

// Perform market trade and check for successful ticket
   string comment = StringFormat("%s,#%d", IntegerToString(_params.GetMagic()), _sTradeDetails.totalPositions);
   long ticket = _tradeManager.Market(orderType, lots, 0.0, 0.0,comment);
   return (ticket > 0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CSmartInvestV3::GetLots()
{
   if(_sTradeDetails.totalPositions < _params.GetLateStart() || !_params.IsMartingale())
      return _params.GetLot();

   double lots =  CRiskService::GetVolumeBasedOnMartinGaleBatch(_sTradeDetails.totalPositions - _params.GetLateStart(), _params.GetFactor(), _params.GetSymbol(), _params.GetLot(), ENUM_TYPE_MARTINGALE_MULTIPLICATION);

   return (lots <= _params.GetMaxLot()) ? lots : _params.GetMaxLot();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CSmartInvestV3::GetStep(void)
{
   return _params.GetStep();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSmartInvestV3::ModifyTrades(ENUM_DIRECTION direction)
{
   if(direction == ENUM_DIRECTION_NEUTRAL)
      return false;

   int type = (int) CEnums::FromDirectionToMarketOrder(direction);

   double takeProfit = CRiskService::AveragingTakeProfitForBatch(type, _params.GetTakeProfit(), _params.GetMagic(), _params.GetSymbol());

   return _tradeManager.ModifyMarketBatch(_params.GetMagic(), 0.0, takeProfit, _params.GetSymbol(), type, LOGGER_PREFIX_ERROR);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION CSmartInvestV3::GetCurrentDirection()
{
   ENUM_DIRECTION directionTemp = ENUM_DIRECTION_NEUTRAL;
   int batchType = -1;
   for(int index = PositionsTotal() - 1 ; index >= 0 && !IsStopped(); index--)
   {
      if(!_positionInfo.SelectByIndex(index))
         continue;

      if(_positionInfo.Symbol() != _params.GetSymbol() || _positionInfo.Magic() != _params.GetMagic())
         continue;

      if(batchType == -1)
      {
         batchType = (int) _positionInfo.PositionType();
         directionTemp = (ENUM_DIRECTION)CTradeUtils::Direction(batchType);
         return directionTemp;
      }

   }
   return directionTemp;
}
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
void CSmartInvestV3::OnReInit(void)
{
   _direction = GetCurrentDirection();
   ModifyTrades(_direction);
}

//+------------------------------------------------------------------+
void CSmartInvestV3::OnTimer_()
{
   if(_params.IsHedge())
      hedge.OnTimer_();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::OnChartEvent_(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(_params.IsHedge())
      hedge.OnChartEvent_(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
void CSmartInvestV3::PrintInputParams()
{

}
//+------------------------------------------------------------------+
void CSmartInvestV3::OnDeinit_(const int reason)
{
#ifdef __MQL5__
   if(reason == REASON_PARAMETERS)
      PrintInputParams();
#endif
}
//+------------------------------------------------------------------+
void CSmartInvestV3::DisplayExpertInfo(void)
{

// hedge.DisplayHedgeDashBoard();
// return;
   string drawDownType = (_params.GetDrawDownType() == ENUM_DRAWDOWN_PERCENTAGE) ? "Percent" : "Cash";
   string space = "                                                                       ";
   string dashboard = space + "SmartInvest Dashboard";
   dashboard += "\n" + space + "Direction: " + EnumToString(_direction);
//dashboard += "\n" + space + "Current Gap: " + IntegerToString(_currentGap);
   dashboard += "\n" + space + "Number of Positions: " + IntegerToString(_sTradeDetails.totalPositions);
   dashboard += "\n" + space + "Next Volume: " + DoubleToString(GetLots(), 2);
   dashboard += "\n" + space + "DrawDown: " + DoubleToString(GetDrawDown(), 4) + " " + drawDownType;
   dashboard += "\n" + space + "Costs: " + DoubleToString(_sTradeDetails.totalCosts, 3);
   dashboard += "\n" + space + "GrossProfit: " + DoubleToString(_sTradeDetails.totalGrossProfit, 2);
   dashboard += "\n" + space + "Spread: " + IntegerToString(CSymbolInfo::GetSpread(_params.GetSymbol()));
   Comment(dashboard);
}
//+------------------------------------------------------------------+
