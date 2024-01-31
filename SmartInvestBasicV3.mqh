//+------------------------------------------------------------------+
//|                                           SmartInvestBasicV3.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"


//LOG LEVEL SET IN PARAMETERS INFO/ERROR sau loge info true sau false

#include <Mircea/_profitpoint/Base/ExpertBase.mqh>
#include <Mircea/_profitpoint/Trade/TradeManager.mqh>
#include <Mircea/RiskManagement/RiskService.mqh>
#include <Mircea/_profitpoint/Mql/CandleInfo.mqh>
#include <Mircea/RiskManagement/RiskService.mqh>
#include <Mircea/ExpertAdvisors/Hedge/HedgeCandles.mqh>


/*
FIXURI
2024.01.12  - Fix pentru lateStart si Multiplier
            - Fix pentru afisarea NextLot in Dashboard  (needsTesting)



BUG cu calcularea distantei -> PriceCurrent vs Price open asta imi compara bid cu ask in loc sa compare bid cu bid si ask cu ask 399 (done)
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
datetime lastOnTimerExecution;
int timeToWaitInTester = 2;
#define  MSC_ON_TIMER  200
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSmartInvestParams : public CAppParams
{
   ObjectAttrProtected(int, Magic);
   ObjectAttrBoolProtected(Martingale);
   ObjectAttrProtected(double, Factor);
   ObjectAttrProtected(int, TakeProfit);
   ObjectAttrProtected(int, Step);
   ObjectAttrProtected(double, Lot);
   ObjectAttrProtected(double, MaxLot);
   ObjectAttrProtected(int, LateStart);
   ObjectAttrBoolProtected(CloseAtDrawDown);
   ObjectAttrProtected(ENUM_DRAWDOWN_TYPE, DrawDownType);
   ObjectAttrProtected(double, DrawDownToCloseValue);
   ObjectAttrProtected(int, MaxTrades);
   ObjectAttrProtected(int, SpreadFilter);


   ObjectAttrBoolProtected(Hedge);
   ObjectAttrProtected(ENUM_DRAWDOWN_TYPE, HedgeDrawDownType);
   ObjectAttrProtected(double, HedgeDrawDownToCloseValue);

   ObjectAttrBoolProtected(DisplayInformaion);
   ObjectAttrProtected(string, Symbol);

public:
   bool               Check() override
   {
      /*
       if(!CMQLInfo::IsTesting_() && !CAccount::IsDemo_())
         {
          Alert("This Expert Advisor is only available on demo accounts or strategy tester");
          return false;
         }
      */
      if(mMagic <= 0)
      {
         Alert("Magic Number cannot be negative");
         return false;
      }
      if(mStep <= 0)
      {
         Alert("Step cannot pe negative or zero");
         return false;
      }
      if(mFactor == 0)
      {
         Alert("Multiplier cannot be zero");
         return false;
      }
      if(CString::IsEmptyOrNull(mSymbol))
      {
         mSymbol = Symbol();
      }

      string message = NULL;
      mLot = (mLot != 0.0) ? mLot : CSymbolInfo::GetMinLot(mSymbol);

      if(!CTradeUtils::IsLotsValid(mLot, mSymbol, message))
      {
         Alert(message);
         return false;
      }

      if(!CTradeUtils::IsLotsValid(mMaxLot, mSymbol, message))
      {
         Alert(message);
         return false;
      }
      if(mHedgeDrawDownToCloseValue <= 0 && mIsHedge)
      {
         LOG_ERROR("Drawdown value for hedge  should pe positive [value >= 0]");
         Alert("Drawdown value for hedge  should pe positive [value >= 0]");
         return false;
      }
      if(mDrawDownToCloseValue <= 0 && mIsCloseAtDrawDown)
      {
         LOG_ERROR("Drawdown value to close should pe positive [value >= 0]");
         Alert("Drawdown value to close should pe positive [value >= 0]");
         return false;
      }

      mDrawDownToCloseValue = -mDrawDownToCloseValue;
      //mHedgeDrawDownToCloseValue = -mHedgeDrawDownToCloseValue;
      if(CMQLInfo::IsTesting_()) //aici e ceva problema
      {
         lastOnTimerExecution =  TimeCurrent();
      }

      //mLateStart = 0;
      mIsHedge = false;
      return true;
   }
};


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSmartInvestV3 : public CExpertAdvisor
{
   ObjectAttrProtected(int, Magic);
   ObjectAttrBoolProtected(Martingale);
   ObjectAttrProtected(double, Factor);
   ObjectAttrProtected(int, TakeProfit);
   ObjectAttrProtected(int, Step);
   ObjectAttrProtected(double, Lot);
   ObjectAttrProtected(double, MaxLot);
   ObjectAttrProtected(int, LateStart);
   ObjectAttrBoolProtected(CloseAtDrawDown);
   ObjectAttrProtected(ENUM_DRAWDOWN_TYPE, DrawDownType);
   ObjectAttrProtected(double, DrawDownToCloseValue);
   ObjectAttrProtected(int, MaxTrades);
   ObjectAttrBoolProtected(DisplayInformaion);
   ObjectAttrProtected(string, Symbol);
   ObjectAttrProtected(int, SpreadFilter);

   ObjectAttrBoolProtected(Hedge);
   ObjectAttrProtected(ENUM_DRAWDOWN_TYPE, HedgeDrawDownType);
   ObjectAttrProtected(double, HedgeDrawDownToCloseValue);
protected:
   datetime          candleTime;
   ENUM_DIRECTION     _direction;
   CPositionInfo      _positionInfo;
   CTradeManager      _tradeManager;
   CHedgeBase*        hedge;
   STradesDetails    _sTradeDetails;
   int                _currentGap;
public:
   ~CSmartInvestV3()
   {
      SafeDelete(hedge);
   }
   CSmartInvestV3(CSmartInvestParams* params)
      :
      mMagic(params.GetMagic()),
      mIsMartingale(params.IsMartingale()),
      mFactor(params.GetFactor()),
      mTakeProfit(params.GetTakeProfit()),
      mStep(params.GetStep()),
      mLot(params.GetLot()),
      mMaxLot(params.GetMaxLot()),
      mLateStart(params.GetLateStart()),
      mIsCloseAtDrawDown(params.IsCloseAtDrawDown()),
      mDrawDownType(params.GetDrawDownType()),
      mDrawDownToCloseValue(params.GetDrawDownToCloseValue()),
      mMaxTrades(params.GetMaxTrades()),
      mSpreadFilter(params.GetSpreadFilter()),
      mIsHedge(params.IsHedge()),
      mHedgeDrawDownType(params.GetHedgeDrawDownType()),
      mHedgeDrawDownToCloseValue(params.GetHedgeDrawDownToCloseValue()),
      mSymbol(params.GetSymbol()),
      mIsDisplayInformaion(params.IsDisplayInformaion())
   {
      if(mIsHedge)
         hedge = new CHedgeCandles(mMagic, mSymbol, mHedgeDrawDownType, mHedgeDrawDownToCloseValue);
      else
         hedge = NULL;

      /*
      if(!mIsHedge)
         hedge.HideAllButtons();
      if(!mIsHedge)
         hedge.RemoveLines();
      */

      _tradeManager.SetMagic(mMagic);
      _tradeManager.SetSymbol(mSymbol);

      CTradeUtils::CalculateTradesDetails(_sTradeDetails, mMagic, mSymbol);
      _direction = GetCurrentDirection();

      candleTime = 0;
      CCandleInfo::IsNewCandle(candleTime, PERIOD_CURRENT, mSymbol);

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
   if(mIsHedge && CMQLInfo::IsTesting_() && TimeCurrent() > lastOnTimerExecution + timeToWaitInTester)
   {
      OnTimer();
      lastOnTimerExecution =  TimeCurrent();
   }

   if(CSymbolInfo::GetSpread(mSymbol) > mSpreadFilter)
      return;

   CTradeUtils::CalculateTradesDetails(_sTradeDetails, mMagic, mSymbol);

   if(_sTradeDetails.totalPositions == 0 && _direction != ENUM_DIRECTION_NEUTRAL)
   {
      _direction = ENUM_DIRECTION_NEUTRAL;
   }

   ManageDrawDown();
   if(mIsHedge)
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
   if(!CCandleInfo::IsNewCandle(candleTime, PERIOD_CURRENT, mSymbol))
      return;
   bool tradeHasOpenedSuccessfully = false;

   if(_sTradeDetails.totalPositions == 0)
   {
      _direction = GetSignalFirstTrade();
      tradeHasOpenedSuccessfully = OpenTrade(_direction);
   }
   else if(_sTradeDetails.totalPositions <= mMaxTrades)
   {
      ENUM_DIRECTION signal = GetSignalSubsequentTrades(_direction);
      tradeHasOpenedSuccessfully = OpenTrade(signal);
   }

   if(tradeHasOpenedSuccessfully)
   {
      ModifyTrades(_direction);
      CTradeUtils::CalculateTradesDetails(_sTradeDetails, mMagic, mSymbol);
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::ManageDrawDown()
{
   if(mIsHedge)
      hedge.Main(_sTradeDetails, _direction);

   if(mIsCloseAtDrawDown)
   {
      double runningProfit = GetDrawDown();
      if(runningProfit > mDrawDownToCloseValue)
         return;

      LOG_INFO(StringFormat("Closing all trades, drawdown on EA reached its value of %s, drawdown close type %s",
                            DoubleToString(runningProfit, 2),
                            EnumToString(mDrawDownType)
                           ));
      int type = CEnums::FromDirectionToMarketOrder(_direction);
      _tradeManager.CloseBatch(mMagic, mSymbol, type);
   }


}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::ManageDashboard()
{
   if(mIsDisplayInformaion)
      DisplayExpertInfo();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CSmartInvestV3::GetDrawDown()
{
   if(mDrawDownType == ENUM_DRAWDOWN_PERCENTAGE)
   {
      return CRiskService::RunningProfitBalancePercent(mMagic, mSymbol);
   }

   if(mDrawDownType == ENUM_DRAWDOWN_CASH)
   {
      return CRiskService::RunningProfitCash(mMagic, mSymbol);
   }

   return DBL_MAX;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION CSmartInvestV3::GetSignalFirstTrade()
{
   return CSymbolInfo::CandleTypeBullishOrBearish(PERIOD_CURRENT, mSymbol);
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

// Return direction based on the distance value
   return (distance < mStep) ? ENUM_DIRECTION_NEUTRAL : _direction;
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
   string comment = StringFormat("%s,#%d", IntegerToString(mMagic), _sTradeDetails.totalPositions + 1);
   long ticket = _tradeManager.Market(orderType, lots, 0.0, 0.0);
   return (ticket > 0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CSmartInvestV3::GetLots()
{
   if(_sTradeDetails.totalPositions < mLateStart || !mIsMartingale)
      return mLot;

   double lots =  CRiskService::GetVolumeBasedOnMartinGaleBatch(_sTradeDetails.totalPositions - mLateStart + 1, mFactor, mSymbol, mLot, ENUM_TYPE_MARTINGALE_MULTIPLICATION);

   return (lots <= mMaxLot) ? lots : mMaxLot;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSmartInvestV3::ModifyTrades(ENUM_DIRECTION direction)
{
   if(direction == ENUM_DIRECTION_NEUTRAL)
      return false;

   int type = (int) CEnums::FromDirectionToMarketOrder(direction);

   double takeProfit = CRiskService::AveragingTakeProfitForBatch(type, mTakeProfit, mMagic, mSymbol);

   return _tradeManager.ModifyMarketBatch(mMagic, 0.0, takeProfit, mSymbol, type, LOGGER_PREFIX_ERROR);
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

      if(_positionInfo.Symbol() != mSymbol || _positionInfo.Magic() != mMagic)
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::DisplayExpertInfo(void)
{

// hedge.DisplayHedgeDashBoard();
// return;
   string drawDownType = (mDrawDownType == ENUM_DRAWDOWN_PERCENTAGE) ? "Percent" : "Cash";
   string space = "                                                                       ";
   string dashboard = space + "SmartInvestBasic Dashboard";
   dashboard += "\n" + space + "Direction: " + EnumToString(_direction);
   dashboard += "\n" + space + "Current Gap: " + IntegerToString(_currentGap);
   dashboard += "\n" + space + "Number of Positions: " + IntegerToString(_sTradeDetails.totalPositions);
   dashboard += "\n" + space + "Next Volume: " + DoubleToString(GetLots(), 2);
   dashboard += "\n" + space + "DrawDown: " + DoubleToString(GetDrawDown(), 4) + " " + drawDownType;
   dashboard += "\n" + space + "Costs: " + DoubleToString(_sTradeDetails.totalCosts, 3);
   dashboard += "\n" + space + "GrossProfit: " + DoubleToString(_sTradeDetails.totalGrossProfit, 2);
   dashboard += "\n" + space + "Spread: " + IntegerToString(CSymbolInfo::GetSpread(mSymbol));
   Comment(dashboard);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::OnReInit(void)
{
   _direction = GetCurrentDirection();
   ModifyTrades(_direction);
}

//+------------------------------------------------------------------+
void CSmartInvestV3::OnTimer_()
{
   if(mIsHedge)
      hedge.OnTimer_();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::OnChartEvent_(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(mIsHedge)
      hedge.OnChartEvent_(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
void CSmartInvestV3::PrintInputParams()
{
   string msg = StringFormat("%s = %s, %s = %s, %s = %s, %s = %s, %s = %s, %s = %s, %s = %s, %s = %s, %s = %s, %s = %s, %s = %s, %s = %s, ",
                             nameOf(mMagic), IntegerToString(mMagic),
                             nameOf(mIsMartingale), CString::FormatBool(mIsMartingale),
                             nameOf(mFactor), DoubleToString(mFactor, 3),
                             nameOf(mTakeProfit), IntegerToString(mTakeProfit),
                             nameOf(mStep), IntegerToString(mStep),
                             nameOf(mLot), DoubleToString(mLot, 3),
                             nameOf(mMaxLot), DoubleToString(mMaxLot, 3),
                             nameOf(mLateStart), IntegerToString(mLateStart),
                             nameOf(mIsCloseAtDrawDown), CString::FormatBool(mIsCloseAtDrawDown),
                             nameOf(mDrawDownType), EnumToString(mDrawDownType),
                             nameOf(mDrawDownToCloseValue), DoubleToString(mDrawDownToCloseValue, 3),
                             nameOf(mMaxTrades), IntegerToString(mMaxTrades)
                            );
   Print(msg);

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
