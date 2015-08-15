package snjdck.fileformat.swf
{
	import flash.factory.newBuffer;
	import flash.utils.ByteArray;
	
	import array.has;
	import array.insert;
	import array.or;
	import array.pushIfNotHas;
	import array.sub;
	
	import snjdck.fileformat.swf.enum.SwfTagType;
	import snjdck.fileformat.swf.utils.RawDict;
	import snjdck.fileformat.swf.utils.generateVariableName;
	
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
		
		private var isCompressed:Boolean;
		private var version:uint;
		private var bodyHead:ByteArray;
		
		private var tagList:Array = [];
		private var abcFileList:Array = [];
		
		private var symbolNames:Array;
		
		public function SwfFile()
		{
			symbolNames = KeyWords.slice();
		}
		
		public function read(file:ByteArray):void
		{
			var sign:String = file.readUTFBytes(3);
			version = file.readUnsignedByte();
			const fileSize:uint = file.readUnsignedInt();//解压后大小,包含头部8字节
			
			const temp:ByteArray = newBuffer();
			bodyHead = newBuffer();
			
			switch(sign.charAt(0)){
				case "C":
					isCompressed = true;
					temp.writeBytes(file, 8);
					temp.uncompress();
					break;
				case "F":
					isCompressed = false;
					temp.writeBytes(file, 8);
					break;
				case "Z":
					isCompressed = true;
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
			file = temp;
			file.position = 0;
			
			const nBit:int = file[0] >>> 3;
			file.readBytes(bodyHead, 0, Math.ceil((nBit*4+5)/8)+4);
			
			parseTags(file);
		}
		
		public function write(output:ByteArray):void
		{
			var body:ByteArray = newBuffer();
			body.writeBytes(bodyHead);
			for each(var tag:SwfTag in tagList){
				tag.write(body);
			}
			
			output.writeUTFBytes(isCompressed ? "CWS" : "FWS");
			output.writeByte(version);
			output.writeUnsignedInt(body.length + 8);
			if(isCompressed){
				body.compress();
			}
			output.writeBytes(body);
		}
		
		private function parseTags(bin:ByteArray):void
		{
			while(bin.bytesAvailable > 0){
				var tag:SwfTag = new SwfTag();
				tag.read(bin);
				parseTag(tag);
			}
		}
		
		private function parseTag(tag:SwfTag):void
		{
			switch(tag.type){
				case SwfTagType.Metadata:
				case SwfTagType.ProductInfo:
				case SwfTagType.EnableDebugger:
				case SwfTagType.EnableDebugger2:
				case SwfTagType.DebugID:
				case SwfTagType.Protect:
					return;//ignore
				case SwfTagType.FileAttributes:
					tag.data[0] &= 0xEF;//hasMetadata = false
					break;
				case SwfTagType.SymbolClass:
					parseSymbolClass(tag.data);
					break;
				case SwfTagType.DoABC2:
					tag.data.readUnsignedInt();//LazyInitializeFlag
					readString(tag.data);//abc file name
					//fall through
				case SwfTagType.DoABC:
					abcFileList.push(new AbcFile(tag.data));
					break;
			}
			tagList.push(tag);
		}
		
		private function parseSymbolClass(source:ByteArray):void
		{
			var count:int = source.readUnsignedShort();
			while(count-- > 0){
				source.readUnsignedShort();
				var clsName:String = readString(source);
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
			
			for each(var str:String in finalList){
				var index:int = str.lastIndexOf(":");
				if(index >= 0){
					var a:String = str.slice(0, index);
					var b:String = str.slice(index+1);
					var hasA:Boolean = array.has(finalList, a);
					var hasB:Boolean = array.has(finalList, b);
					if(hasA || hasB){
						rawDict.addData(str, [a, b]);
					}
					continue;
				}
				var mixStr:String = generateVariableName(str.length, mixList, true);
				rawDict.addData(str, mixStr);
			}
			
			rawDict.mixPackage();
			
			for each(abcFile in abcFileList){
				abcFile.mixCode(rawDict);
			}
			trace("---blackList------",blackList.length);
			trace(blackList.join("\n"));
			trace("---whiteList------",whiteList.length);
			trace(whiteList.join("\n"));
			trace("---finalList------",finalList.length);
			trace(finalList.join("\n"));
			trace("---finalDict------");
			trace(rawDict);
		}
		
		private function isFullClassName(clsName:String):Boolean
		{
			var index:int = clsName.lastIndexOf(":");
			if(index < 0){
				return false;
			}
			return true;
		}
		/*
		public function addTelemetryTag():void
		{
			const index:int = getTagIndex(SwfTagType.FileAttributes);
			if(-1 == index){
				return;
			}
			
			var tag:SwfTag = new SwfTag();
			tag.type = SwfTagType.EnableTelemetry;
			tag.size = 2;
			tag.data = newBuffer(null, 2);
			
			insert(tagList, index+1, tag);
		}
		
		private function getTagIndex(tagType:uint):int
		{
			for(var i:int=0; i<tagList.length; i++){
				var tag:SwfTag = tagList[i];
				if(tag.type == tagType){
					return i;
				}
			}
			return -1;
		}
		//*/
	}
}