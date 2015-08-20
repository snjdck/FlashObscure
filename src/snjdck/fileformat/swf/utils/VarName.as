package snjdck.fileformat.swf.utils
{
	import flash.utils.getTimer;
	
	import array.has;
	
	import stdlib.random.RandomUtil;
	
	final public class VarName
	{
		static private const Var1:Array = [
			36,95,//$,_
			65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,//A-Z
			97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122//a-z
		];
		static private const Var2:Array = [
			36,95,//$,_
			48,49,50,51,52,53,54,55,56,57,//0-9
			65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,//A-Z
			97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122//a-z
		];
		static private const charCodeList:Array = [];
		
		static public function Gen(source:String, excludeList:Array=null, addResultToExcludeList:Boolean=false):String
		{
			var nChar:int = source.length;
			assert(nChar > 0);
			var timestamp:int = getTimer();
			var result:String;
			do{
				charCodeList.length = 0;
				charCodeList.push(RandomUtil.getArrayItem(Var1));
				while(charCodeList.length < nChar){
					charCodeList.push(RandomUtil.getArrayItem(Var2));
				}
				result = String.fromCharCode.apply(null, charCodeList);
				if(getTimer() - timestamp >= 1000){
					return source;
				}
			}while(excludeList && has(excludeList, result));
			if(excludeList && addResultToExcludeList){
				excludeList.push(result);
			}
			return result;
		}
	}
}