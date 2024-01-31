//+------------------------------------------------------------------+
//|                                                         Main.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"


#include "SmartInvestBasicV3.mqh"


LOGGER_DEFINE_FILENAME("SmartInvestBasic");

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
BEGIN_INPUT(CSmartInvestParams)
INPUT(int, Magic, 1);               //Magic
INPUT(bool, Martingale, false);     //Use Martingale
INPUT(double, Factor, 1.0);         //Multiplier
INPUT(int, TakeProfit, 500);        //TakeProfit (Pipette/Points)
INPUT(int, Step, 2000);              //Step (Pipette/Points)
INPUT(double, Lot, 0.0);            //Lots(0.0 = MinLot)
INPUT(double, MaxLot, 1);           //Max Lot
INPUT(int, LateStart, 5);          //Late Start
//INPUT_SEP("Exit");
INPUT(bool, CloseAtDrawDown, true); //Close at drawdown (Drawdown on EA)
INPUT(ENUM_DRAWDOWN_TYPE, DrawDownType, ENUM_DRAWDOWN_PERCENTAGE); //Drawdown Type
INPUT(double, DrawDownToCloseValue, 5);  //Drawdown to close
//INPUT_SEP("Pause");
INPUT(int, MaxTrades, 100);        //Max Trades
INPUT(int, SpreadFilter, 50);      //Spread Filter
//INPUT_SEP("Hedging_NotApplicable"); // Hedging Not/Applicable
FIXED_INPUT(bool, Hedge, false); //Use Hedge
FIXED_INPUT(ENUM_DRAWDOWN_TYPE, HedgeDrawDownType, ENUM_DRAWDOWN_CASH); // Hedge Drawdown Type
FIXED_INPUT(double, HedgeDrawDownToCloseValue, 100);  // Hedge Drawdown to close
//INPUT_SEP("Miscelaneous");
INPUT(bool, DisplayInformaion, false);//Display Information Status
END_INPUT
//+------------------------------------------------------------------+
DECLARE_EA(CSmartInvestV3, true, CAppNameProvider::GetAppName(EA_SmartInvestBasicMP));
//+------------------------------------------------------------------+
