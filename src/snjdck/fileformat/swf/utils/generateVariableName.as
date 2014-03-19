package snjdck.fileformat.swf.utils
{
	import array.has;
	
	import stdlib.constant.Char;
	import stdlib.random.random_string;

	public function generateVariableName(nChar:int, excludeList:Array=null, addResultToExcludeList:Boolean=false):String
	{
		if(nChar < 1){
			throw new ArgumentError("nChar must > 0");
		}
		
		var str:String;
		
		do{
			str = random_string(Char.Var1);
			if(nChar > 1){
				str += random_string(Char.Var2, nChar-1);
			}
		}while(excludeList && array.has(excludeList, str));
		
		if(excludeList && addResultToExcludeList){
			excludeList.push(str);
		}
		
		return str;
	}
}