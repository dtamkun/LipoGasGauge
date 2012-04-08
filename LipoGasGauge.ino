//-----------------------------------------------------------------------
//         Program: Lipo Gas Gauge
//         $Author: davidtamkun $
//
// Source/Based On: Sample App by J.C. Woltz
//
//         History: DMT 02/22/2011 Created Original Version
//                  DMT 02/23/2011 v1.1.0 LCD to use i2c
//                  DMT 02/26/2011 V1.1.1 LCD using SPI.  Unable to get Log Shield Working
//                  DMT ??/??/2011 V1.2.0 
//                  DMT 03/31/2011 V1.3.0 Attempting to get Log Shield Working
//                  DMT 05/15/2011 V1.4.0 Giving up on Logging Shield for now.
//                                        Renamed file to LipoGasGauge.pde and
//                                        will keep under SVN going forward.
//                                        Added SVN Header Info and code
//                                        to display SVN Info
//                  DMT 05/28/2011 V1.4.0 Rev 46, 50 - still trying to get to work with
//                                        Nokia LCD.  Still having problems.  Rev 50
//                                        Working again with BIG LCD.
//                  DMT 05/30/2011 V1.5.0 Got this code working with Nokia Display on the
//                                        Mega and added % of Battery Capacity on the 20x4 LCD
//                  DMT 05/30/2011 V1.5.1 Confirmed that the Nokia LCD display now works on the
//                                        Uno.
//                  DMT 05/31/2011 V1.5.2 Corrected Nokia LCD display if current flow was
//                                        more than 5 characters.
//                  DMT 06/04/2011 V1.5.3 Enabled Gas Gauge Sleep Mode and Power Switch On/Off
//                                        code works, but needs improvement.
//                  DMT 06/05/2011 V1.6.0 Battery Capacity is now stored in the EEPROM of the
//                                        Gas Gauge chip, instead of being hardcoded.  Also
//                                        you can now set/reset the battery capacity and
//                                        accumulated current (gas level) from a menu
//                                        on the Serial Monitor.
//                  DMT 06/11/2011 V1.6.2 Added the capability to turn sleep mode on and
//                                        off from the serial menu.
//                  DMT 06/12/2011 V2.0.0 Split DS2764 code off into separate files which could
//                                        be in a separate library.  Removed old code from
//                                        logging shield and most of the debug code.  Also removed
//                                        all the version display code to get the memory size down.
//                                        Added logic to check for Discharges of more than 999 mA
//                                        and eliminated the decimal point for these values to
//                                        prevent the display from getting messed up.
//                  DMT 06/18/2011 V2.1.0 Moved DS2764 code into a separate library.
//                  DMT 07/09/2011 V2.2.0 Some code cleanup, tested to make sure this works with
//                                        the Nokia LCD.  Other Displays have not been tested
//                                        recently, so the #defines may not work.  Memory
//                                        continues to be a challenge, and this version 
//                                        just barely fits onto an UNO.
//                  DMT 09/17/2011 V2.3.0 Adjusting to use newer version of PCD8554 Library that
//                                        inherits from the Print Class.  Eliminating use of
//                                        PString class to reduce memory requirements.
//                  DMT 04/08/2012 V2.4.0 Arduino 1.0 compatible, added additional function to
//                                        refresh battery capacity, added a #define to set the
//                                        refresh interval, which is now 500 instead of 1000
//
//    Compiliation: Arduino IDE
//
//        Hardware: Arduino Uno - ATMEGA328P-PU - 16Mhz
//
//      Components: Gas Gauge on Proto Board with: 
//                       Maxim DS2764+025 Lipo Protector Chip
//                            i2C Slave Address 0x34
//
//                  HD44780 Character 20x4 LCD (White on Blue) <== NOT Tested Recently
//                  LCD Backback from Adafruit
//                  -- OR --
//                  Nokia LCD Display using PCD8544 driver chip
//                
//       Libraries: Wire/Liquid Crystal if using LCD Display
//                  PCD8544 if using Nokia Display
//
//   Communication: Uses i2C for Gas Gauge
//                       SPI for LCD or Nokia LCD
//
//         Voltage: 5 Volts OK, but Nokia Display needs 3.3v
//
//          Status: Experimental
//                  Work in Progress
//                  Stable                  <=========
//                  Complete
//
//          Wiring: LCD Backback from Adafruit
//                  ---------------------------------------------------
//                  SPI LCDBpck    Arduino
//                  -----------    -------
//                  GRN LATCH      D4      SPI Latch
//                  YEL DATA       D3      SPI Data
//                  ORN CLK        D2      SPI Clock
//                  RED +5V        +5v
//                  BLK GND        GND
//
//
//                  Dave's LCD Backpack for Nokia LCD Display - PCD8544
//                  ---------------------------------------------------
//                  MyBkpk         Arduino         Device
//                  Color          Pin             Pin
//                  ------         -------         ------
//                  Brown          GND             GND
//                  Red            +5V             VCC & Bklight LED
//                  Orange         D3              RST*
//                  Yellow         D4              CS*
//                  Green          D5              D/C*
//                  Blue           D6              DIN*
//                  Purple         D7              SCLK*
//                                                 * Level shifted
//
//
//                  Gas Gauge Chip Proto Board - Maxim DS2764+025
//                  ---------------------------------------------------
//                  Shield         Arduino
//                  -----------    -------
//                  GND            GND     Ground
//                  DATA Yellow    A4      i2C Data    (pin 20 on Mega)
//                  CLK  Orange    A5      i2C Clock   (pin 21 on Mega)
//                  
//-----------------------------------------------------------------------
/////////////////////////////////////////////////////////////////////
// Example Test application for the Maxim DS2764 IC. 
// A LiPo protection IC
/////////////////////////////////////////////////////////////////////
// J.C. Woltz 2010.11.15
/////////////////////////////////////////////////////////////////////
// This work is licensed under the Creative Commons 
// Attribution-ShareAlike 3.0 Unported License. To view a copy of 
// this license, visit http://creativecommons.org/licenses/by-sa/3.0/
// or send a letter to 
// Creative Commons, 
// 171 Second Street, 
// Suite 300, 
// San Francisco, California, 94105, USA.
/////////////////////////////////////////////////////////////////////



//******************************************************************************
//** Define Options
//******************************************************************************
#define REFRESH_MILLIS 500    // # of milliseconds between each refresh of display
                              // 1000 = 1 second
                              
#define SMALL_LCD      1      //Use 16x2 LCD - not really big enough to use
#define BIG_LCD        2      //Use 20x4 LCD
#define NOKIA_LCD      3      //Use 14x6 Nokia LCD Display - 84x48 pixels
#define TFT_LCD_1_8    4    // Use 1.8" TFT LCD Display with SD Card
#define TFT_LCD_2_8    5    // Use 2.8" TFT LCD Display
#define TFT_LCD_2_8_TOUCH_SHIELD    6    // use 2.8" TFT LCD Touch Shield Display with SD Card

//** Choose one of these displays
#define DISPLAY_TYPE   NOKIA_LCD
//#define DISPLAY_TYPE   BIG_LCD
//#define DISPLAY_TYPE   0
//#define DISPLAY_TYPE    TFT_LCD_2_8_TOUCH_SHIELD    


#if DISPLAY_TYPE == SMALL_LCD
#define NUMCOLS        16    // number of LCD Columns
#define NUMROWS        2     // number of LCD Lines
#define LINEBUFSIZE    NUMCOLS + 1

#elif DISPLAY_TYPE == BIG_LCD
#define NUMCOLS        20    // number of LCD Columns
#define NUMROWS        4     // number of LCD Lines
#define LINEBUFSIZE    NUMCOLS + 1

#elif DISPLAY_TYPE == NOKIA_LCD || DISPLAY_TYPE == TFT_LCD_2_8_TOUCH_SHIELD
#define NUMCOLS        14    // number of LCD Columns
#define NUMROWS         6    // number of LCD Lines
#define LINEBUFSIZE    (NUMCOLS * NUMROWS) + 1    // 6 lines of 14 characters plus trailing NULL

#else
// Define these anyway so our buffers are defined
#define NUMCOLS        20
#define NUMROWS        1
#define LINEBUFSIZE    NUMCOLS + 1
#endif




// String Buffer Sizes
#define FLOATBUFSIZE        10    // size for buffer string to contain character equivalents of floating point numbers
#define LOGBUFSIZE          20    // number of characters for a line written to the log
#define DATEBUFSIZE         NUMCOLS + 1
#define REVISIONBUFSIZE     NUMCOLS + 1

#define TEMPBUFSIZE         FLOATBUFSIZE + 1
#define CURRENTBUFSIZE      FLOATBUFSIZE + 1
#define VOLTBUFSIZE         FLOATBUFSIZE + 1




//******************************************************************************
//** Include Library Code
//******************************************************************************
#include <avr/pgmspace.h>   // needed for PROGMEM
//#include <PString.h>
#include <Wire.h>           // required for I2C communication with Gas Gauge
#include <DS2764.h>

#if DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD
#include <LiquidCrystal.h>
#elif DISPLAY_TYPE == NOKIA_LCD
#include <PCD8544.h>
#elif DISPLAY_TYPE == TFT_LCD_2_8_TOUCH_SHIELD
#include <SD.h>
#include <SPI.h>
#include "TFTLCD.h"
#endif













//******************************************************************************
//** Declare Global Variables
//******************************************************************************
//      char gszLineBuf[LINEBUFSIZE];
//      char gszTempBuf[TEMPBUFSIZE];
//      char gszCurrBuf[CURRENTBUFSIZE];
//      char gszPctBuf[TEMPBUFSIZE];
//      char gszVoltBuf[VOLTBUFSIZE];
      
//  PString  pstrLine   (gszLineBuf, LINEBUFSIZE);
//  PString  pstrTemp   (gszTempBuf, TEMPBUFSIZE);
//  PString  pstrCurrent(gszCurrBuf, CURRENTBUFSIZE);
//  PString  pstrPercent(gszPctBuf,  TEMPBUFSIZE);
//  PString  pstrVolts  (gszVoltBuf, VOLTBUFSIZE);
      
// a bitmap of a degree symbol
static unsigned char __attribute__ ((progmem)) degree_bmp[]={0x06, 0x09, 0x09, 0x06, 0x00};

const char helpText[]PROGMEM =
    "\n"
    "Available commands:" "\n"
    "  <nnnn> c   - Sets Battery Capacity.  Entering '1200 c' sets the" "\n"
    "               battery capacity to 1,200 mAh." "\n"
    "  <nnnn> a   - Sets the Accumulated Current to the specified number" "\n"
    "               of mAH.  Entering '1200 a' sets the battery level to" "\n"
    "               1200 mAh." "\n"
    "     <n> s   - Turn Sleep Mode ON or OFF.  Entering '1 s' Enables Sleep Mode" "\n"
    "               while '0 s' disables Sleep Mode" "\n"
    "         h   - Redisplays this menu" "\n"
    "         x   - Clears the input buffer for this menu." "\n"
;


/* Older Text - too many options and string literals to use with the Nokia LCD
    "\n"
    "Available commands:" "\n"
    "  <nnnn> c   - Sets Battery Capacity.  Entering '1200 c' sets the" "\n"
    "               battery capacity to 1,200 mAh." "\n"
    "  <nnnn> a   - Sets the Accumulated Current to the specified number" "\n"
    "               of mAH.  Entering '1200 a' sets the battery level to" "\n"
    "               1200 mAh." "\n"
    "         f   - Reset Protection Flags and Disable Charging and Discharging." "\n"
    "         n   - Reset Protection Flags and Enable Charging and Discharging." "\n"
    "         r   - Refresh Data from Chip." "\n"
    "     <n> s   - Turn Sleep Mode ON or OFF.  Entering '1 s' Enables Sleep Mode" "\n"
    "               while '0 s' disables Sleep Mode" "\n"
    "  <nnnn> o   - Sets the current offset -- NOT IMPLEMENTED!" "\n"
    "         d   - Displays current info" "\n"
    "         h   - Redisplays this menu" "\n"
    "         x   - Clears Input Buffer" "\n"
*/
    
    

DS2764 gasGauge     = DS2764();
int    giDoIt       = 0;
int    giInputVal   = 0;




#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD
// initialize the library with the numbers of the interface pins
// for plain connection
//LiquidCrystal lcd(2, 3, 4, 5, 6, 7 );

// for i2C
//LiquidCrystal lcd(0);

// Connect via SPI. Data pin is #3, Clock is #2 and Latch is #4
// make degree symbol for LCD
uint8_t degree[8]  = {140,146,146,140,128,128,128,128};

LiquidCrystal lcd(3, 2, 4);

#elif DISPLAY_TYPE == NOKIA_LCD
//
//PCD8544(int8_t SCLK, int8_t DIN, int8_t DC, int8_t CS, int8_t RST)
PCD8544 nokia = PCD8544(7, 6, 5, 4, 3);
//PCD8544 nokia = PCD8544(2, 3, 5, 6, 7);
//PCD8544 nokia = PCD8544(9, 8, 7, 6, 5);

#elif DISPLAY_TYPE == TFT_LCD_2_8_TOUCH_SHIELD

// These are the pins as connected in the shield
#define LCD_CS A3    // Chip Select goes to Analog 3
#define LCD_CD A2    // Command/Data goes to Analog 2
#define LCD_WR A1    // LCD Write goes to Analog 1
#define LCD_RD A0    // LCD Read goes to Analog 0

// The chip select pin for the SD card on the shield
#define SD_CS 5 
// In the SD card, place 24 bit color BMP files (be sure they are 24-bit!)
// There are examples in the sketch folder

// our TFT wiring
TFTLCD tft(LCD_CS, LCD_CD, LCD_WR, LCD_RD, 0);

// the file itself
//File bmpFile;

// information we extract about the bitmap file
int bmpWidth, bmpHeight;
uint8_t bmpDepth, bmpImageoffset;

/************* HARDWARE SPI ENABLE/DISABLE */
// we want to reuse the pins for the SD card and the TFT - to save 2 pins. this means we have to
// enable the SPI hardware interface whenever accessing the SD card and then disable it when done
int8_t saved_spimode;


#endif





//******************************************************************************
//** Start Main Logic
//******************************************************************************


//------------------------------------------------------------------------------
// setup
//
// First function run by the microcontroller and is used to initialize and 
// set up variables and classes.
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void setup() { 
    Serial.begin(9600);          // start serial communication at 9600bps
    delay(500);
    
    //fillBuffer(gszLineBuf, LINEBUFSIZE, '\0');
    //fillBuffer(gszTempBuf, TEMPBUFSIZE, '\0');
    //fillBuffer(gszCurrBuf, CURRENTBUFSIZE,  '\0');
    //fillBuffer(gszVoltBuf, VOLTBUFSIZE, '\0');

    Wire.begin();        // join i2c bus (address optional for master)
    
    delay(500);
    gasGauge.dsInit();   // this call fails to get the battery 
                         // capacity at startup.
    
    delay(500);
       
#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD    
    // set up the LCD's number of rows and columns:
    lcd.begin(NUMCOLS, NUMROWS);
    lcd.createChar(0, degree);
    
#elif DISPLAY_TYPE == NOKIA_LCD
    nokia.init();
    nokia.clear();
    
#elif DISPLAY_TYPE == TFT_LCD_2_8_TOUCH_SHIELD

  tft.reset();
  
  // find the TFT display
  uint16_t identifier = tft.readRegister(0x0);
  if (identifier == 0x9325) {
    Serial.println("Found ILI9325");
  } else if (identifier == 0x9328) {
    Serial.println("Found ILI9328");
  } else {
    Serial.print("Unknown driver chip ");
    Serial.println(identifier, HEX);
    while (1);
  }  
 
  tft.initDisplay();
  // the image is a landscape, so get into landscape mode
  tft.setRotation(1);

  Serial.print("Initializing SD card...");
 
  if (!SD.begin(SD_CS)) {
    Serial.println("failed!");
    return;
  }
  Serial.println("SD OK!");
  
  //bmpFile = SD.open("tiger.bmp");

  //if (! bmpFile) {
  //  Serial.println("didnt find image");
  //  while (1);
  //}
  
  //if (! bmpReadHeader(bmpFile)) { 
  //   Serial.println("bad bmp");
  //   return;
  //}
  
  //Serial.print("image size "); 
  //Serial.print(bmpWidth, DEC);
  //Serial.print(", ");
  //Serial.println(bmpHeight, DEC);
  //disableSPI();    // release SPI so we can use those pins to draw
 
  //bmpdraw(bmpFile, 0, 0);
  // disable the SD card interface after we are done!
  //disableSPI();
}


#endif
    
    gasGauge.dsSetPowerSwitchOn();
    delay(500);
    
    // Reset any Protection Flags, so the Gas Gauge can re-evaluate them  
    gasGauge.dsResetProtection(DS_RESET_ENABLE);
    
    // force a refresh of battery capacity, since it wasn't 
    // always happening in the call to dsInit
    delay(500);
    gasGauge.dsReloadBatteryCapacity();

    showHelp();  
   
} 







//------------------------------------------------------------------------------
// loop
//
// Function called repeatedly after setup completes.  You must never "return"
// from this function.  Your main code execution goes here.
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void loop() { 
    
    gasGauge.dsRefresh();
    
    DisplayData();
    
    if (Serial.available()) {
        handleInput(Serial.read());
    }

    delay(REFRESH_MILLIS);    
} 





#if DISPLAY_TYPE == TFT_LCD_2_8_TOUCH_SHIELD
void disableSPI(void) {
  saved_spimode = SPCR;
  SPCR = 0;
}

void enableSPI(void) {
  SPCR = saved_spimode; 
}
#endif








void DisplayData() {
  
    //Serial.println("Entering DisplayData()");
    int   i           = 0;
    int   iPrecision  = 1;
    char  szHi[]      = "HI";
    char  szLo[]      = "LO";
    char  szOk[]      = "Ok";
    char  szOn[]      = "On ";
    char  szOff[]     = "Off";
    char* szVoltStat  = NULL;
    char* szChrgStat  = NULL;
    char* szDChrgStat = NULL;
    char* szChrgOn    = NULL;
    char* szDChrgOn   = NULL;

    
    //pstrTemp.begin();
    //pstrCurrent.begin();
    //pstrPercent.begin();
    //pstrVolts.begin();
    
    if(gasGauge.dsGetCurrent() < -999.9) {
        iPrecision = 0;   
    }
    else {
        iPrecision = 1;
    }
    
    //pstrCurrent.print(gasGauge.dsGetCurrent(),               iPrecision);    
    //pstrTemp.print   (gasGauge.dsGetTempF(),                          1);        
    //pstrPercent.print(gasGauge.dsGetBatteryCapacityPercent(),         1);
    //pstrVolts.print ((gasGauge.dsGetBatteryVoltage() / 1000.0),       2);
    
    // set Voltage Status
    i = gasGauge.dsGetVoltageStatus();
    if (i == DS_VOLTS_HI) { 
        szVoltStat = szHi; 
    }
    else if (i == DS_VOLTS_LOW) { 
        szVoltStat = szLo; 
    }
    else {
        szVoltStat = szOk; 
    }

    i = gasGauge.dsGetChargeStatus();
    // set Charge Current Status
    if (i == DS_CHARGE_CURRENT_HI) {
        // charge current is over the threshold 
        szChrgStat = szHi;
    }
    else {
        szChrgStat = szOk;
    }     

    if (gasGauge.dsIsChargeOn()) { 
        szChrgOn = szOn;
    }
    else {
        szChrgOn = szOff;
    }


    i = gasGauge.dsGetDischargeStatus();
    // set Discharge Current Status
    if (i == DS_DISCHARGE_CURRENT_HI) {
        // discharge current is over the threshold 
        szDChrgStat = szHi; 
    }
    else {
        szDChrgStat = szOk; 
    } 
    
    
    if (gasGauge.dsIsDischargeOn()) { 
        szDChrgOn = szOn;
    }
    else {
        szDChrgOn = szOff;
    }
    
    /*        
    if (iProtect & DS00CE) { 
        Serial.println("           Charging: Enabled"); 
    }
    else {
        Serial.println("           Charging: Disabled");
    }
    
    if (iProtect & DS00DE) { 
        Serial.println("        Discharging: Enabled");
    }
    else {
        Serial.println("        Discharging: Disabled");
    }
    */        

    
    // these are the global buffers
    //char   gszTempBuf[FLOATBUF    + 1];
    //char   gszCurrBuf[FLOATBUF    + 1];
    //char   gszLineBuf[NUMCOLS     + 1];
            
    // LCD Lines
    //         1  1  1   2
    //12345678901234567890
    //   -0.6mA     4191mV
    //Acc: 2110mAh  78.4oF
    //VOLT CHARGE  DCHARGE
    // OK  OK ON    HI OFF
    //
    
#if  DISPLAY_TYPE == SMALL_LCD || DISPLAY_TYPE == BIG_LCD
    
    // Line 1
    // 12345678901234567890
    //   150.0mA     4200mV
    pstrLine.begin();
    pstrLine.format("%7smA     %4dmV", gszCurrBuf, gasGauge.dsGetBatteryVoltage());
    lcd.setCursor(0, 0);
    lcd.print(pstrLine);

    // Line 2
    // 12345678901234567890
    // 6600mAh 99.1% 102.2o
    pstrLine.begin();
    pstrLine.format("%4dmAh%5s%% %5s", gasGauge.dsGetCurrent(), gszPctBuf, gszTempBuf);
            
    lcd.setCursor(0, 1);
    lcd.print(pstrLine);
    lcd.print(0, BYTE);

    // Line 3        
    lcd.setCursor(0, 2);
    //         12345678901234567890
    lcd.print("VOLT CHARGE  DCHARGE");
    
    
    pstrLine.begin();
    pstrLine.format(" %2s  %2s %3s   %3s %3s", szVoltStat, szChrgStat, szChrgOn, szDChrgStat, szDChrgOn)
    
    lcd.setCursor(0, 3);
    lcd.print(pstrLine);
            

#elif DISPLAY_TYPE == NOKIA_LCD

    //Serial.println("In Display Data for Nokia Screen");
    
    //pstrLine.begin();
    nokia.clear();    // clear the screen

    //Serial.println("got past Nokia.clear");
    
    
    //01234567890123
    //999.9mA 110.5o
    //2180mAh  99.9%
    //Voltage     OK
    //Charging    OK
    //Discharge   OK
    
    //123456789012341234567890123412345678901234123456789012341234567890123412345678901234
    //--------------==============--------------==============--------------==============
    //-700.0mA 3.78V1000mAh ---.-%Voltage     OKCharge  Off OKDCharge Off OKTemp:  102.6oF


    //pstrLine.format("%6smA%5sV%4dmAh %5s%%Voltage     %2sCharge  %3s %2sDcharge %3s %2sTemp:  %5s F", 
    //                gszCurrBuf, gszVoltBuf, gasGauge.dsGetAccumulatedCurrent(), gszPctBuf, szVoltStat, szChrgOn, szChrgStat, szDChrgOn, szDChrgStat, gszTempBuf);
                    
    //nokia.drawstring(0, 0, gszLineBuf);
    // old debug lineSerial.println(gszLineBuf);
    
    // Current Pad
    // >= 0  < 10    pad 3
    // >= 10 < 100   pad 2
    // >= 100 < 1000 pad 1
    // 
    
    printPaddedFloat(gasGauge.dsGetCurrent(), 6, iPrecision);
    nokia.print("mA");
    printPaddedFloat((gasGauge.dsGetBatteryVoltage() / 1000.0), 5, 2);
    nokia.print("V");
    
    printPaddedFloat(gasGauge.dsGetAccumulatedCurrent(), 4, 0);
    nokia.print("mAh ");
    printPaddedFloat(gasGauge.dsGetBatteryCapacityPercent(), 5, 1);
    nokia.print("%Voltage     ");
    nokia.print(szVoltStat);
    
    nokia.print("Charge  ");
    nokia.print(szChrgOn);
    nokia.print(" ");
    nokia.print(szChrgStat);
    
    nokia.print("DCharge ");
    nokia.print(szDChrgOn);
    nokia.print(" ");
    nokia.print(szDChrgStat);
    
    nokia.print("Temp:  ");
    printPaddedFloat(gasGauge.dsGetTempF(), 5, 1);
    nokia.print(" F");
        
    if (!(gasGauge.dsIsChargeEnabled())) {
        // Charging is disabled 
        nokia.drawline(0, 3*8 + 4, 7*6, 3*8 + 4, BLACK); 
    }
    
    if (!(gasGauge.dsIsDischargeEnabled())) {
        //Discharging is disabled 
        nokia.drawline(0, 4*8 + 4, 7*6, 4*8 + 4, BLACK); 
    }
    
    nokia.drawbitmap(72, 40, degree_bmp, 5, 8, BLACK);
    
    nokia.display();


#elif DISPLAY_TYPE == TFT_LCD_2_8_TOUCH_SHIELD

    tft.fillScreen(BLACK);
    tft.setCursor(0, 20);
    tft.setTextColor(RED);
    tft.setTextSize(1);
    tft.println("Hello World!");
    tft.setTextSize(2);
    tft.println(1234.56);
    tft.setTextSize(3);
    tft.println(0xDEADBEEF, HEX);



    
#endif
}
















//------------------------------------------------------------------------------
// fillBuffer
//
// Fills the specified character array with the specified character
//
// Arguments:
//     None
//
// Return Value:
//     None
//------------------------------------------------------------------------------
void fillBuffer(char* aszBuff, int aiSize, char acChar) {

  int i = 0;

  for(i = 0; i < aiSize; i++) {
    aszBuff[i] = acChar;
  }  
}








static void handleInput (char c) {
    if ('0' <= c && c <= '9') {
        giInputVal = 10 * giInputVal + c - '0';
    }
    else if ('a' <= c && c <='z') {
        
        switch (c) {
            default:
                showHelp();
                break;
            case 'c': // setBatteryCapacity
                Serial.print("Setting Battery Capacity to ");
                Serial.print(giInputVal, DEC);
                Serial.println(" mAh...");
                gasGauge.dsSetBatteryCapacity(giInputVal);
                delay(100);
                
                
                
                Serial.print("Battery Capacity Set now set to ");
                Serial.print(gasGauge.dsGetBatteryCapacity(), DEC);
                Serial.println(" mAh.");
                
                giInputVal = 0;
                break;
            case 'a': // set Accumulated Current
                Serial.print("Setting Accumulated Current to ");
                Serial.print(giInputVal, DEC);
                Serial.println(" mAh...");
                
                gasGauge.dsSetAccumCurrent(giInputVal);
                
                Serial.println("Accumulated Current set.");
             
                giInputVal = 0;
                break;
            case 's': // Set Sleep Mode On or Off
                if(giInputVal > 0) {
                    gasGauge.dsEnableSleep();
                }
                else {
                    gasGauge.dsDisableSleep();
                }                
                Serial.println("Sleep Mode Updated.");
                giInputVal = 0;
                break;
 /*               
            case 'f':    // reset dsProtection and disable power in and out
                gasGauge.dsResetProtection(DS_RESET_DISABLE);
                delay(100);
                gasGauge.dsRefresh();
                Serial.println("Reset and Disabled.");
                giInputVal = 0;
                break;               
            case 'n':    // reset dsProtection and enable power in and out
                gasGauge.dsResetProtection(DS_RESET_ENABLE);
                delay(100);
                Serial.println("Refreshing...");
                gasGauge.dsRefresh();
                Serial.println("Reset and Enabled.");
                giInputVal = 0;
                break;
            case 'r': // refresh
                gasGauge.dsRefresh();
                Serial.println("Refresh Complete.");
                giInputVal = 0;
                break;
            case 'o': // This will be a place to set the Current Offset.
                giInputVal = 0;
                break;
            case 'd': // display giInputVal
                // retrieve protection and status settings again
                gasGauge.dsRefresh();
                delay(100);
                Serial.println("Current Values:");
                Serial.print  ("                 Volts: ");
                Serial.println(gasGauge.dsGetBatteryVoltage(), DEC);
                Serial.print  ("               Current: ");
                Serial.println(gasGauge.dsGetCurrent(), 1);
                Serial.print  ("   Accumulated Current: ");
                Serial.println(gasGauge.dsGetAccumulatedCurrent(), DEC);
                Serial.print  ("                Temp F: ");
                Serial.println(gasGauge.dsGetTempF(), 1);
                Serial.print  ("          Power On Ind: ");
                if(gasGauge.dsIsPowerOn()) {
                    Serial.println("ON");
                }
                else {
                    Serial.println("Off");
                }
                Serial.print  ("      Battery Capacity: ");
                Serial.println(gasGauge.dsGetBatteryCapacity(), DEC);
                Serial.print  ("            Sleep Mode: ");
                if(gasGauge.dsIsSleepEnabled()) {
                    Serial.println("Enabled");
                }
                else {
                    Serial.println("Disabled");
                }
                Serial.print  ("        Voltage Status: ");
                Serial.println(gasGauge.dsGetVoltageStatus(), DEC);
                
                //              1234567890123456789012v
                Serial.print  ("         Charge Status: ");
                Serial.println(gasGauge.dsGetChargeStatus(), DEC);
                
                 
                if(gasGauge.dsIsChargeOn()) { 
                    //              1234567890123456789012v
                    Serial.println("           Charging is: ON");
                }
                else {
                    Serial.println("           Charging is: OFF");
                }
                
                if(gasGauge.dsIsChargeEnabled()) { 
                    Serial.println("           Charging is: Enabled");
                }
                else {
                    Serial.println("           Charging is: Disabled");
                }
                
                //              1234567890123456789012v
                Serial.print  ("      Discharge Status: ");
                Serial.println(gasGauge.dsGetDischargeStatus(), DEC);

               if(gasGauge.dsIsDischargeOn()) { 
                    //              1234567890123456789012v
                    Serial.println("        Discharging is: ON");
                }
                else {
                    Serial.println("        Discharging is: OFF");
                }
                
                if(gasGauge.dsIsDischargeEnabled()) { 
                    Serial.println("        Discharging is: Enabled");
                }
                else {
                    Serial.println("        Discharging is: Disabled");
                }
 
                if(gasGauge.dsIsPowerOn()) {
                    Serial.println("              Power is: ON");
                }
                else {
                    Serial.println("              Power is: OFF");
                }

                //              1234567890123456789012v
                Serial.print  ("  Numeric Input Buffer: ");
                Serial.println(giInputVal, DEC);
                break;
                
            case 'h': // display menu again
                showHelp();
                break;
            case 'x': // clear out giInputVal without running a command.
                giInputVal = 0;
                showHelp();
                Serial.println("Input Buffer Cleared");
                break; */
        }
    } else if (c > ' ')
        showHelp();
}




void printPaddedFloat(float afVal, int aiWidth, int aiPrecision) {
    // pad = width - signwidth - sigdig - precision - decimalwidth
    int signWidth    = 0;
    int decimalWidth = 0;
    int significantDigits = 0;
    int padWidth = 0;
    int i = 0;

    if(afVal < 0.0) {
        signWidth = 1;
    }    
    
    if(aiPrecision > 0) {
        decimalWidth = 1;
    }
    
    if(abs(afVal) < 10.0) {
        significantDigits = 1;
    }
    else if(abs(afVal) < 100.0) {
        significantDigits = 2;
    }
    else if(abs(afVal) < 1000.0) {
        significantDigits = 3;
    }
    else if(abs(afVal) < 10000.0) {
        significantDigits = 4;
    }
    else {
        significantDigits = 5;
    }
    
    padWidth = aiWidth - signWidth - significantDigits - aiPrecision - decimalWidth;
    
    for(i = 1; i <= padWidth; i++) {
        nokia.print(" ");
    }
    
    nokia.print(afVal, aiPrecision);
    
}



static void showString (const char* s) {
    for (;;) {
        char c = pgm_read_byte(s++);
        if (c == 0)
            break;
        if (c == '\n')
            Serial.print('\r');
        Serial.print(c);
    }
}



static void showHelp () {
    showString(helpText);
}






