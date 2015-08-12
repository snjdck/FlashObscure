package snjdck.fileformat.abc.io
{
	import flash.utils.ByteArray;

	final public class Reader
	{
		static public function ReadS32(data:ByteArray):int
		{
			var result:uint = 0;
			var count:int = 0;
			do{
				var byte:uint = data.readUnsignedByte();
				result |= (byte & 0x7f) << (count * 7);
				++count;
			}while((byte & 0x80) != 0 && count < 5);
			return result;
		}
		
		static public function ReadS24(data:ByteArray):int
		{
			var result:int = data.readUnsignedByte();
			result |= data.readUnsignedByte() << 8;
			result |= data.readByte() << 16;
			return result;
		}
	}
}