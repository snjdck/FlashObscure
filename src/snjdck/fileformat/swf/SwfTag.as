package snjdck.fileformat.swf
{
	import flash.utils.ByteArray;
	
	final internal class SwfTag
	{
		public var type:uint;
		public var size:uint;
		public var dataBegin:int;
		public var dataEnd:int;
		
		public function SwfTag()
		{
		}
		
		public function read(bin:ByteArray):void
		{
			var flag:uint = bin.readUnsignedShort();
			type = flag >>> 6;
			size = flag & 0x3F;
			if(0x3F == size){
				size = bin.readInt();
			}
			dataBegin = bin.position;
			dataEnd = dataBegin + size;
		}
		/*
		public function write(bin:ByteArray):void
		{
			var flag:uint = type << 6;
			if(size >= 0x3F){
				flag |= 0x3F;
				bin.writeShort(flag);
				bin.writeInt(size);
			}else{
				flag |= size;
				bin.writeShort(flag);
			}
			if(size > 0){
				bin.writeBytes(data, 0, size);
			}
		}
		//*/
	}
}