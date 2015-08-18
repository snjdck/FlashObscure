package snjdck.fileformat.swf
{
	import flash.factory.newBuffer;
	import flash.utils.ByteArray;
	
	import array.or;
	import array.pushIfNotHas;
	import array.sub;
	
	import snjdck.fileformat.swf.enum.SwfTagType;
	import snjdck.fileformat.swf.utils.RawDict;
	
	import stream.readString;

	public class SwfFile
	{
		[Embed("keywords.bin", mimeType="application/octet-stream")]
		static private const CLS_KEYWORDS:Class;
		static private function InitKeyWords(bin:ByteArray):Array
		{
			bin.uncompress("lzma");
			var list:Array = [];
			while(bin.bytesAvailable > 0){
				list.push(bin.readUTF());
			}
			return list;
		}
		static private const KeyWords:Array = InitKeyWords(new CLS_KEYWORDS());
		static private const tag:SwfTag = new SwfTag();
		
		private var fileHead:ByteArray;
		private var fileBytes:ByteArray;
		private var abcFileList:Array = [];
		
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
				var clsName:String = readString(fileBytes);
				var index:int = clsName.lastIndexOf(".");
				if(index != -1){
					pushIfNotHas(symbolNames, clsName.slice(0, index));
					pushIfNotHas(symbolNames, clsName.slice(index+1));
				}
				pushIfNotHas(symbolNames, clsName);
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