package snjdck.fileformat.swf
{
	import flash.factory.newBuffer;
	import flash.utils.ByteArray;
	
	import array.has;
	import array.or;
	import array.pushIfNotHas;
	import array.sub;
	
	import snjdck.fileformat.swf.enum.SwfTagType;
	import snjdck.fileformat.swf.utils.RawDict;
	
	import stdlib.constant.CharSet;
	
	import stream.readString;
	
	import string.trim;

	public class SwfFile
	{
		[Embed("keywords.txt", mimeType="application/octet-stream")]
		static private const CLS_KEYWORDS:Class;
		static private function InitKeyWords(bin:ByteArray):Array
		{
			return trim(bin.toString()).split(/\s+/);
		}
		static private const KeyWords:Array = InitKeyWords(new CLS_KEYWORDS());
		static private const tag:SwfTag = new SwfTag();
		
		private var fileHead:ByteArray;
		private var fileBytes:ByteArray;
		private var abcFileList:Array = [];
		private var symbolClsDict:Object = {};
		
		private var symbolNames:Array;
		
		public function SwfFile()
		{
			symbolNames = KeyWords.slice();
		}
		
		public function write(output:ByteArray):void
		{
			if(fileHead[0] != 0x46){
				fileBytes.compress();
			}
			output.writeBytes(fileHead);
			output.writeBytes(fileBytes);
		}
		
		public function read(file:ByteArray):void
		{
			fileHead = newBuffer();
			const temp:ByteArray = newBuffer();
			
			file.readBytes(fileHead, 0, 8);
			fileHead.position = 4;
			var fileSize:uint = fileHead.readUnsignedInt();//解压后大小,包含头部8字节
			
			switch(fileHead[0]){
				case 0x46:
					temp.writeBytes(file, 8);
					break;
				case 0x43:
					temp.writeBytes(file, 8);
					temp.uncompress();
					break;
				case 0x5A:
					fileHead[0] = 0x43;
					temp.writeBytes(file, 12, 5);
					temp.writeUnsignedInt(fileSize-8);
					temp.writeUnsignedInt(0);
					temp.writeBytes(file, 17);
					temp.uncompress("lzma");
					break;
				default:
					throw new Error("file is not swf!");
			}
			
			file.clear();
			fileBytes = temp;
			fileBytes.position = 0;
			
			const nBit:int = fileBytes[0] >>> 3;
			fileBytes.position += Math.ceil((nBit*4+5)/8) + 4;
			
			while(fileBytes.bytesAvailable > 0){
				tag.read(fileBytes);
				parseTag(tag);
				assert(fileBytes.position == tag.dataEnd);
			}
		}
		
		private function parseTag(tag:SwfTag):void
		{
			switch(tag.type){
				case SwfTagType.SymbolClass:
					parseSymbolClass();
					break;
				case SwfTagType.DoABC2:
					fileBytes.readUnsignedInt();//LazyInitializeFlag
					readString(fileBytes);//abc file name
					//fall through
				case SwfTagType.DoABC:
					abcFileList.push(new AbcFile(fileBytes));
					break;
				default:
					fileBytes.position = tag.dataEnd;
			}
		}
		
		private function parseSymbolClass():void
		{
			var count:int = fileBytes.readUnsignedShort();
			while(count-- > 0){
				fileBytes.readUnsignedShort();
				var offset:uint = fileBytes.position;
				var clsName:String = readString(fileBytes);
				symbolClsDict[clsName] = offset;
			}
		}
		
		public function mixCode():void
		{
			var rawDict:RawDict = new RawDict();
			var abcFile:AbcFile;
			
			var strList:Array = [];
			var whiteList:Array = [];
			var blackList:Array = [];
			
			for each(abcFile in abcFileList){
				abcFile.collect(strList, whiteList, blackList);
			}
			
			var finalList:Array = array.sub(whiteList, blackList);
			finalList = array.sub(finalList, symbolNames);
			var mixList:Array = array.or(strList, symbolNames);
			
			rawDict.mixStr(finalList, mixList);
			
			for(var key:String in symbolClsDict){
				var mixedStr:String = rawDict.getValue(key);
				if(mixedStr != null){
					fileBytes.position = symbolClsDict[key];
					fileBytes.writeMultiByte(mixedStr, CharSet.ASCII);
					assert(fileBytes.readUnsignedByte() == 0);
				}
			}
			
			for each(abcFile in abcFileList){
				abcFile.mixCode(rawDict);
			}
			strList = array.sub(whiteList, finalList);
			trace("---subList------",strList.length);
			for each(var str:String in strList){
				trace(array.has(blackList, str), array.has(symbolNames, str), str);
			}
			trace("---finalDict------");
			trace(rawDict);
		}
	}
}