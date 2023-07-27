//+------------------------------------------------------------------+
//|                                           SmartInvestBasicV3.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"




#include <Mircea/_profitpoint/Base/ExpertBase.mqh>
#include <Mircea/_profitpoint/Trade/TradeManager.mqh>
#include <Mircea/RiskManagement/RiskService.mqh>
#include <Mircea/_profitpoint/Mql/CandleInfo.mqh>
#include <Mircea/RiskManagement/RiskService.mqh>
#include <Mircea/ExpertAdvisors/Hedge/HedgeBase.mqh>
/*

Panou nu comment astea  ->

Panel pt EA
expected profit
next lot
direction
lock
running lots,
running profit
nr trades
LastError (cand am debug sau nu neaparat) to decide


*/
/*
In Base
RENAMe
checkConfliences -> checkConflForOpen
add checkForClose
add new candle in base

Check direction On Init
Remove  CRiskStrategyAveragfingMartingale Pointer


LOCK

pot sa am mai multe clase Lock.HandleLock
Si sa am o clasa Locks.Create (ENUM_LOCK_STRATEGY) -> returneaza un new Lock



Sa am grija cum fac cu drawdown to close sa il fac cu -1* sau ceva


Convert Risk& to risk in money si cand e calculcat sa il transforme inapoi in bani
if(balanceParam != CAccount::Balance() && riskType == PERCENT)
   -> recalculate mRiskValue

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
                     ObjectAttrBoolProtected(CloseAtDrawDown);
                     ObjectAttrProtected(ENUM_RISK_TYPE, DrawDownType);
                     ObjectAttrProtected(double, DrawDownToCloseValue);
                     ObjectAttrProtected(uint, MaxTrades);
                     ObjectAttrBoolProtected(DisplayInformaion);
                     ObjectAttrProtected(string, Symbol);

public:
   bool               Check() override
   {
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


      if(!CTradeUtils::IsLotsValid(mLot, mSymbol))
      {
         Alert("Invalid Lots for %s", mSymbol);
         return false;
      }

      if(mDrawDownType != ENUM_RISK_CASH && mDrawDownType != ENUM_RISK_PERCENT_BALANCE)
      {
         Alert("Drawdown type is not supported, please select other value");
         return false;
      }

      if(mDrawDownToCloseValue < 0)
      {
         Alert("Drawdown value should pe positive [value > 0]");
         return false;
      }
      mDrawDownToCloseValue = -mDrawDownToCloseValue;
      return true;


      if(CMQLInfo::IsTesting_())
      {
         OnTimer();
         lastOnTimerExecution =  TimeCurrent();
      }

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
                     ObjectAttrBoolProtected(CloseAtDrawDown);
                     ObjectAttrProtected(ENUM_RISK_TYPE, DrawDownType);
                     ObjectAttrProtected(double, DrawDownToCloseValue);
                     ObjectAttrProtected(uint, MaxTrades);
                     ObjectAttrBoolProtected(DisplayInformaion);
                     ObjectAttrProtected(string, Symbol);
protected:


   ENUM_DIRECTION     _direction;

   CPositionInfo      _positionInfo;
   CTradeManager      *_tradeManager;
   CCandleInfo        candleInfo; //rename to _candleINfo

   CHedgeBase        hedge;


   STradesDetails    _sTradeDetails;

   int                _currentGap;

public:
                    ~CSmartInvestV3()
   {
      SafeDelete(_tradeManager);

   }
                     CSmartInvestV3(CSmartInvestParams* params)
      :
                     mMagic(params.GetMagic()),
                     mIsMartingale(params.IsMartingale()),
                     mFactor(params.GetFactor()),
                     mTakeProfit(params.GetTakeProfit()),
                     mStep(params.GetStep()),
                     mLot(params.GetLot()),
                     mIsCloseAtDrawDown(params.IsCloseAtDrawDown()),
                     mDrawDownType(params.GetDrawDownType()),
                     mDrawDownToCloseValue(params.GetDrawDownToCloseValue()),
                     mMaxTrades(params.GetMaxTrades()),
                     mSymbol(params.GetSymbol()),
                     mIsDisplayInformaion(params.IsDisplayInformaion()),
                     hedge(mMagic, mSymbol, mDrawDownType, mDrawDownToCloseValue)
   {
      //hedge = CHedgeBase(mMagic, mSymbol, mDrawDownType, mDrawDownToCloseValue);

      _tradeManager = new CTradeManager();
      _tradeManager.SetMagic(mMagic);
      _tradeManager.SetSymbol(mSymbol);

      CTradeUtils::CalculateTradesDetails(_sTradeDetails, mMagic, mSymbol);
      _direction = GetCurrentDirection();

      candleInfo.AddNewSymbolIfNotExists(mSymbol);
      //Modifiy TP but also checkForModify
      OnReInit();

      SetupMillisTimer(MSC_ON_TIMER);

   }

   //Expert Advisor Specific
public:
   virtual void       Main();
   virtual void       OnTrade_() {}
   virtual void       OnTimer_();
   virtual void       OnChartEvent_(const int id, const long &lparam, const double &dparam, const string &sparam);
protected:
   virtual void      OnReInit() {}

   //SmartInvestSpecific
protected:
   virtual ENUM_DIRECTION     GetSignalFirstTrade();
   virtual ENUM_DIRECTION     GetSignalSubsequentTrades(ENUM_DIRECTION direction); //rename this into GetSignalNextTrade /Subsequent
   virtual ENUM_DIRECTION     GetCurrentDirection();


   virtual bool               OpenTrade(ENUM_DIRECTION direction);
   virtual bool               ModifyTrades(ENUM_DIRECTION direction);

   virtual bool               CheckDrawDownToClose();
   virtual double             GetDrawDown();



   virtual void      ManageTrades();
   virtual void      ManageDrawDown();
   virtual void      ManageDashboard();

   //DashBoardSettings
   virtual void      AddLineToDashboard(string& dashboard, string fieldName, string value);
   virtual void      DisplayExpertInfo();
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::Main()
{

   if(CMQLInfo::IsTesting_() && TimeCurrent() > lastOnTimerExecution + timeToWaitInTester)
   {
      OnTimer();
      lastOnTimerExecution =  TimeCurrent();
   }

   CTradeUtils::CalculateTradesDetails(_sTradeDetails, mMagic, mSymbol);

   if(_sTradeDetails.totalPositions == 0 && _direction != ENUM_DIRECTION_NEUTRAL)
   {
      _direction = ENUM_DIRECTION_NEUTRAL;
   }

   ManageDrawDown();
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
   if(!candleInfo.IsNewCandleTry(mSymbol, PERIOD_CURRENT))
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
   if(true) //mIsHedging
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
   if(mDrawDownType == ENUM_RISK_PERCENT_BALANCE)
   {
      return CRiskService::RunningProfitBalancePercent(mMagic, mSymbol);
   }

   if(mDrawDownType == ENUM_RISK_CASH)
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
   if (direction == ENUM_DIRECTION_NEUTRAL)
      return direction;

// Determine the positionTicket based on the direction
   long positionTicket = (_direction == ENUM_DIRECTION_BULLISH)
                         ? (long)_sTradeDetails.lowestLevelBuyPosTicket
                         : (long)_sTradeDetails.highestLevelSellPosTicket;

// If position selection by ticket fails, log error and return neutral direction
   if (!_positionInfo.SelectByTicket(positionTicket))
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
   double priceCurrent = _positionInfo.PriceCurrent();

   int distance = CTradeUtils::DistanceBetweenTwoPricesPoints(
                     _direction == ENUM_DIRECTION_BULLISH ? priceOpen : priceCurrent,
                     _direction == ENUM_DIRECTION_BULLISH ? priceCurrent : priceOpen,
                     _positionInfo.Symbol());

   _currentGap = distance;

// Return direction based on the distance value
   return (distance < mStep) ? ENUM_DIRECTION_NEUTRAL : _direction;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSmartInvestV3::OpenTrade(ENUM_DIRECTION direction = ENUM_DIRECTION_NEUTRAL)
{
   if (direction == ENUM_DIRECTION_NEUTRAL) return false;

// Determine the number of lots to trade based on Martingale settings
   double lots = mIsMartingale
                 ? CRiskService::GetVolumeBasedOnMartinGaleBatch(_sTradeDetails.totalPositions, mFactor, mSymbol, mLot, ENUM_TYPE_MARTINGALE_MULTIPLICATION)
                 : mLot;

// Convert the direction into a market order type
   int orderType = CEnums::FromDirectionToMarketOrder(direction);
   if (orderType < 0) return false; // If conversion fails, return false

// Perform market trade and check for successful ticket
   long ticket = _tradeManager.Market(orderType, lots, 0.0, 0.0);
   return (ticket > 0);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSmartInvestV3::ModifyTrades(ENUM_DIRECTION direction)
{
   if(direction == ENUM_DIRECTION_NEUTRAL)    return false;

   int type = (int) CEnums::FromDirectionToMarketOrder(direction);

   double takeProfit = CRiskService::AveragingTakeProfitForBatch(type, mTakeProfit, mMagic, mSymbol);

   return _tradeManager.ModifyMarketBatch(mMagic, 0.0, takeProfit, mSymbol, type, LOGGER_PREFIX_ERROR);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_DIRECTION CSmartInvestV3::GetCurrentDirection()
{
   bool allTradesSameDirection = true;
   int batchType = -1;
   for(int index = PositionsTotal() - 1 ; index >= 0 && !IsStopped(); index--)
   {
      if(!_positionInfo.SelectByIndex(index))
      {
         continue;
      }

      if(_positionInfo.Symbol() != mSymbol || _positionInfo.Magic() != mMagic)
      {
         continue;
      }

      if(batchType == -1)
      {
         batchType = (int) _positionInfo.PositionType();
         _direction = (ENUM_DIRECTION)CTradeUtils::Direction(batchType);
      }

      if(batchType != (int) _positionInfo.PositionType())
      {
         int pressed = MessageBox(StringFormat("Continue with Trades of type %s ?", EnumToString((ENUM_POSITION_TYPE)batchType)), "ERR MULTIPLE TRADE TYPES FOUND", MB_ICONERROR | MB_YESNO | MB_DEFBUTTON2);
         if(pressed == IDYES)
         {
            _direction = (ENUM_DIRECTION)CTradeUtils::Direction(batchType);
            break;
         }

         pressed = MessageBox(StringFormat("Continue with Trades of type %s ?", EnumToString((ENUM_POSITION_TYPE)_positionInfo.PositionType())), "ERR MULTIPLE TRADE TYPES FOUND", MB_ICONERROR | MB_YESNO | MB_DEFBUTTON2);

         if(pressed == IDYES)
         {
            _direction = (ENUM_DIRECTION)CTradeUtils::DirectionOpposite(batchType);
            break;
         }
         ExpertRemove();
      }
   }
   return _direction;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::DisplayExpertInfo(void)
{
   string space = "                                                                       ";
   string dashboard = space + "Information Dashboard";
   dashboard += "\n" + space + "Direction: " + EnumToString(_direction);
   dashboard += "\n" + space + "Current Gap: " + IntegerToString(_currentGap);
   dashboard += "\n" + space + "Number of Positions: " + IntegerToString(_sTradeDetails.totalPositions);
   dashboard += "\n" + space + "Next Volume: " + DoubleToString(CRiskService::GetVolumeBasedOnMartinGaleBatch(_sTradeDetails.totalPositions, mFactor, mSymbol, mLot, ENUM_TYPE_MARTINGALE_MULTIPLICATION));
   dashboard += "\n" + space + "DrawDown: " + DoubleToString(GetDrawDown());
   dashboard += "\n" + space + "Costs: " + DoubleToString(_sTradeDetails.totalCosts, 2);
   dashboard += "\n" + space + "GrossProfit: " + DoubleToString(_sTradeDetails.totalGrossProfit, 2);
   dashboard += "\n" + space + "Spread: " + IntegerToString(CSymbolInfo::GetSpread(mSymbol));
   Comment(dashboard);
}

//+------------------------------------------------------------------+
void CSmartInvestV3::OnTimer_()
{
   hedge.OnTimer_();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSmartInvestV3::OnChartEvent_(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   hedge.OnChartEvent_(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
