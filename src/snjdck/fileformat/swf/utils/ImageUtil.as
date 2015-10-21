package snjdck.fileformat.swf.utils
{
	import flash.utils.ByteArray;

	public class ImageUtil
	{
		static private const pngHead:Array = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
		static private const gifHead:Array = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61];
		
		static public function isPng(ba:ByteArray):Boolean
		{
			return doCompare(ba, pngHead);
		}
		
		static public function isGif(ba:ByteArray):Boolean
		{
			return doCompare(ba, gifHead);
		}
		
		static private function doCompare(ba:ByteArray, bytes:Array):Boolean
		{
			var offset:uint = ba.position;
			for(var i:int=0; i<bytes.length; ++i){
				if(ba[offset+i] != bytes[i]){
					return false;
				}
			}
			return true;
		}
	}
}