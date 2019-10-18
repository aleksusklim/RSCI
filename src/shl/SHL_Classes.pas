unit SHL_Classes; // SpyroHackingLib is licensed under WTFPL

{= SWITCHES =}

// {$DEFINE SHL_GRAPHICS} // use Graphics unit
// {$DEFINE SHL_SOUNDS} // use MMSystem unit

interface

// Name convention:

// Txxx - object class
// Sxxx - static class
// Rxxx - record or static array
// Axxx - dynamic array
// Nxxx - enum type

uses
{$IFDEF SHL_GRAPHICS}
  SHL_VramManager, SHL_Bitmaps, SHL_TextureManager, SHL_GoldenFont,
{$ENDIF}
{$IFDEF SHL_SOUNDS}
  SHL_PlayStream,
 {$ENDIF}
  SHL_ProcessStream, SHL_LameStream, SHL_WaveStream, SHL_IsoReader, SHL_Progress,
  SHL_XaMusic, SHL_EccEdc, SHL_GmlModel, SHL_Files, SHL_ObjModel,
  SHL_BufferedStream, SHL_Models3D, SHL_WadManager, SHL_TextUtils, SHL_PosWriter,
  SHL_MemoryManager;

type

 {$IFDEF SHL_GRAPHICS}
  TVram = SHL_VramManager.TVram;

  RPalette = SHL_Bitmaps.RPalette;

  SBitmaps = SHL_Bitmaps.SBitmaps;

  TTextureManager = SHL_TextureManager.TTextureManager;

  TGoldenFont = SHL_GoldenFont.TGoldenFont;

  RGoldModel = SHL_GoldenFont.RGoldModel;

  AGoldModel = SHL_GoldenFont.AGoldModel;

  SGoldModel = SHL_GoldenFont.SGoldModel;
  {$ENDIF}

  {$IFDEF SHL_MMSYSTEM}

  TPlayStream = SHL_PlayStream.TPlayStream;
  {$ENDIF}

  TWaveStream = SHL_WaveStream.TWaveStream;

  TLameStream = SHL_LameStream.TLameStream;

  TProcessStream = SHL_ProcessStream.TProcessStream;

  TIsoReader = SHL_IsoReader.TIsoReader;

  NImageFormat = SHL_IsoReader.NImageFormat;

  TConsoleProgress = SHL_Progress.TConsoleProgress;

  TXaDecoder = SHL_XaMusic.TXaDecoder;

  TEccEdc = SHL_EccEdc.TEccEdc;

  NGmlPrimitive = SHL_GmlModel.NGmlPrimitive;

  TGmlModel = SHL_GmlModel.TGmlModel;

  SFiles = SHL_Files.SFiles;

  RFindFile = SHL_Files.RFindFile;

  AFindFile = SHL_Files.AFindFile;

  RHandles = SHL_Files.RHandles;

  TObjModel = SHL_ObjModel.TObjModel;

  TBufferedRead = SHL_BufferedStream.TBufferedRead;

  TBufferedWrite = SHL_BufferedStream.TBufferedWrite;

  RPoint = SHL_Models3D.RPoint;

  RVertex = SHL_Models3D.RVertex;

  RColor = SHL_Models3D.RColor;

  RFace = SHL_Models3D.RFace;

  RQuad = SHL_Models3D.RQuad;

  RTextureQuad = SHL_Models3D.RTextureQuad;

  RQuadData = SHL_Models3D.RQuadData;

  RVramTexture = SHL_Models3D.RVramTexture;

  RPolyVertex = SHL_Models3D.RPolyVertex;

  RPolyQuad = SHL_Models3D.RPolyQuad;

  RBox = SHL_Models3D.RBox;

  SModels3D = SHL_Models3D.SModels3D;

  NGame = SHL_WadManager.NGame;

  RLevelPart = SHL_WadManager.RLevelPart;

  ALevelPart = SHL_WadManager.ALevelPart;

  RLevelData = SHL_WadManager.RLevelData;

  ALevelData = SHL_WadManager.ALevelData;

  TWadManager = SHL_WadManager.TWadManager;

  STextUtils = SHL_TextUtils.STextUtils;

  TPosWriter = SHL_PosWriter.TPosWriter;

  TMemorySimple = SHL_MemoryManager.TMemorySimple;

implementation

end.

