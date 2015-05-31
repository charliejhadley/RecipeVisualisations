(* ::Package:: *)

BeginPackage["RecipeClassifier`"]

cuisineRecipes::usage="Lookup table for recipes from specific cuisines, use as cuisineRecipes[\"African`";
cuisines::usage="Cuisines available in the dataset";

cuisineClassifierMeasurements::usage="cuisineClassifierMeasurements[trainFrac,data,options] trains a classifier using trainFrac of data with any available options for Classify, returning a ClassifierMeasurements object testing remaining data";
cuisineClassifierInteractive::usage="Outputs an interactive element to classify a recipe provided by the user"


Begin["`Private`"]
(*Import data*)
packageLocation=FileNameDrop[$InputFileName];
recipesImport=Import[FileNameJoin[{packageLocation,"data","recipes.csv"}]];


(*build data structures*)
cuisines=Union@recipesImport[[All,1]];
cuisineRecipes=AssociationThread[cuisines,Map[Cases[recipesImport,{#,a:__}:>{a}]&,cuisines]];

(*balance cuisines to have 352 ingredients, except for Northern Europe from which there are only 250 recipes*)
balancedRecipes$352=Association@Map[If[#=="NorthernEuropean",#->cuisineRecipes[#],#->RandomSample[cuisineRecipes[#],352]]&,Keys[cuisineRecipes]]

(*calculate ClassPriors*)
classPriors=Association@With[{totalRecipes=Length@Flatten[Values[balancedRecipes$352],1]},Map[#->(Length[balancedRecipes$352[#]]/totalRecipes)&,cuisines]]
(*Test a fraction of recipes against a cuisine classifier using this object:*)
cuisineClassifierMeasurements[trainFrac_,data_,clsfyOptions:OptionsPattern[]]:=
Module[
{
trainPoses,
testPoses,
classifyData,
classifier,
measureData,
measures
},
trainPoses=Map[
With[{len=Length[data[#]]},
RandomSample[Range@len,Round[trainFrac*len]]]&,cuisines];
testPoses=MapThread[Complement[Range[Length[data[#1]]],#2]&,{cuisines,trainPoses}];

classifyData=Flatten@MapThread[Part[data[#1],#2]/.q:{__String}:>Rule[q,#1]&,{cuisines,trainPoses}];

classifier=Classify[classifyData,clsfyOptions];

measureData=Flatten[MapThread[Part[data[#1],#2]/.q:{__String}:>Rule[q,#1]&,{cuisines,testPoses}]];

measures=ClassifierMeasurements[classifier,measureData]

]

(*Interactive element*)
cuisineClassifierInteractive[]:=DynamicModule[{ingrs,ingrVars,ingr,ingrSlc,cuisineTest=Null},
ingrVars=Table[Unique[ingr],{3}];
ingrs=Map[ingrSlc[#]&,ingrVars];
ingrSlc[var_]:=DynamicModule[{},Row[{InputField[Dynamic[var],String,FieldHint->"Ingredient",ContinuousAction->False],Spacer[5],Button["Remove",
With[{pos=Position[ingrVars,var][[1]]},
ingrs=Delete[ingrs,pos];ingrVars=Delete[ingrVars,pos]],
Method->"Queued",Enabled->If[Dynamic[Length[ingrVars]<=2],False,True]]}]];
Column[{Dynamic@Row[{Button["Add another ingredient",With[{new=Unique[ingr]},AppendTo[ingrVars,new];AppendTo[ingrs,ingrSlc[new]]]],Button["Start a fresh recipe",ingrVars={Unique[ingr],Unique[ingr]};ingrs=Map[ingrSlc[#]&,ingrVars];cuisineTest=Null]}],
Dynamic[Column[Flatten@ingrs]],
Button["Divine Cuisine",
If[Count[ingrVars,_String]<=2,CreateDialog[{ExpressionCell[Column[{"Please enter more than two ingredients",DefaultButton[]},Alignment->Center],"Output"]}],
cuisineTest=(*recipeclassifier3[StringJoin[Riffle[Dynamic[ingrVars]," "]],"DistributionList"]*)classifyIngrs[ingrVars,"Probabilities"][[1]]]],Dynamic@If[cuisineTest===Null,"",Legended[
Column[{Style["The recipe you've typed is most likely to be: "<>StringJoin@Riffle[MaximalBy[Transpose[{Keys[cuisineTest],Values[cuisineTest]}],Last][[All,1]]," or ",{2,-2,2}],"Text"]
,
BarChart[Values[cuisineTest],ChartLabels->Placed[ToString[NumberForm[#*100,2]]<>"%"&/@Values[cuisineTest],Above],ColorFunction->Function[{height},ColorData["Rainbow"][height]],ImageSize->500]}]

,
With[{cuisine=Keys[cuisineTest],scores=Values[cuisineTest]},
Grid[MapThread[{Graphics[{ColorData["Rainbow"][Rescale[#2,{Min[scores],Max[scores]}]],Rectangle[]},AspectRatio->1,ImageSize->15],#1}&,{cuisine,scores}],Alignment->{Center,Center}]]]
]}],Initialization:>(classifyIngrs[ingrs_List,prop_]:=With[{fix=StringReplace[ingrs," "->"_"]},recipeClassifier[{ToLowerCase@fix},prop]])
,SaveDefinitions->True
]


End[]

EndPackage[]

