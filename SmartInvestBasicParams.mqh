//+------------------------------------------------------------------+
//|                                       SmartInvestBasicParams.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"



datetime lastOnTimerExecution;
int timeToWaitInTester = 2;
#define  MSC_ON_TIMER  200


#include <Mircea/_profitpoint/Base/ExpertBase.mqh>
#include <Mircea/_profitpoint/Trade/TradeManager.mqh>
#include <Mircea/RiskManagement/RiskService.mqh>
#include <Mircea/_profitpoint/Mql/CandleInfo.mqh>
#include <Mircea/RiskManagement/RiskService.mqh>
#include <Mircea/ExpertAdvisors/Hedge/HedgeCandles.mqh>


const ulong __authorizedAccounts[] = {522562,533331,533332};

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

      if(!CAuthorization::Authorize(__authorizedAccounts))
      {
         Alert("This Expert Advisor is only available on demo accounts or strategy tester");
         return false;
      }
      /*
            if(!CMQLInfo::IsTesting_() && !CAccount::IsDemo_())
            {
               Alert("This Expert Advisor is only available on demo accounts or strategy tester");
               return false;
            }
      */

      //if(!CMQLInfo::IsTesting_()) return false;

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

public:
   virtual void      PrintParameters()
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
};
//+------------------------------------------------------------------+
