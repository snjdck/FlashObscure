package snjdck.fileformat.swf
{
	import flash.factory.newBuffer;
	import flash.utils.ByteArray;
	
	import array.has;
	import array.insert;
	import array.pushIfNotHas;
	
	import dict.getKeys;
	import dict.toArray;
	
	import snjdck.fileformat.swf.enum.SwfTagType;
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
		private var sign:String;
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
			sign = file.readUTFBytes(3);
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
			
			output.writeUTFBytes(sign);
			output.writeByte(version);
			output.writeUnsignedInt(body.length + 8);
			if(isCompressed){
				body.compress();
			}
			output.writeBytes(body);
		}
		
		static private const tagToIngore:Array = [SwfTagType.Metadata, SwfTagType.ProductInfo];
		private function parseTags(bin:ByteArray):void
		{
			while(bin.bytesAvailable > 0){
				var tag:SwfTag = new SwfTag();
				tag.read(bin);
				if(has(tagToIngore, tag.type)){
					continue;
				}
				tagList.push(tag);
				parseTag(tag);
			}
		}
		
		private function parseTag(tag:SwfTag):void
		{
			switch(tag.type){
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
			var dic:Object = {};
			var abcFile:AbcFile;
			for each(abcFile in abcFileList){
				abcFile.collectStr(symbolNames, dic);
			}
			for(var key:String in dic){
				dic[key] = generateVariableName(key.length, [], true);
			}
			for each(abcFile in abcFileList){
				abcFile.mixCode(symbolNames, dic);
			}
			trace("-----------");
			trace(dict.toArray(dic).join("\n"));
		}
		
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
	}
}