(* ::Package:: *)

BeginPackage["RecipeVisualisations`"]

cuisineRecipes::usage="Lookup table for recipes from specific cuisines, use as cuisineRecipes[\"African`";
cuisines::usage="Cuisines available in the dataset";
recipleLengthDistViewer::usage="Interactive DistributionChart inspecting the number of ingredients per recipe across different cuisines";
cuisineGeoGraphic::usage="Map of the world with geologically defined cuisines overlain as tooltips";
cuisineGraph::usage="cuisineGraph[cuisine] generates a graph connecting all ingredients used together within recipes from the specified cuisine";
ingrSubGraph::usage"ingrSubGraph[cuisine,ingr] generates a subgraph of all recipes from cuisine containing all ingredients used in combination with the specified ingr";
cuisineIngrConnectivity::usage="cuisineIngrConnectivity[cuisine] generates a profile of the connectivity of ingredients within the specified cuisine";

graphTest=Import[FileNameJoin[{FileNameDrop[$InputFileName],"data","African"<>"Graph.wdx"}]];

Begin["`Private`"]
(*Import data*)
recipesImport=Import[FileNameJoin[{FileNameDrop[$InputFileName],"data","recipes.csv"}]];
packageLocation=FileNameDrop[$InputFileName];

(*build data structures*)
cuisines=Union@recipesImport[[All,1]];
cuisineRecipes=AssociationThread[cuisines,Map[Cases[recipesImport,{#,a:__}:>{a}]&,cuisines]];

(*Interactive DistributionChart-based element*)
recipleLengthDistViewer[]:=Manipulate[
DistributionChart[
	data, ChartLabels->(Rotate[Style[#,"Subsubsection"],90Degree]&/@cuisines), ChartStyle->"Pastel",
	GridLines->{None, If[
		overallAverage,
		{{Mean[Length/@Flatten[Values[cuisineRecipes],1]],Directive[Thick,Black]}},
		None]
	},ChartElementFunction->chartType,ImageSize->500],
{{overallAverage,True,Style["Overall Average","Text",FontSize->16]},{True,False}},
{{chartType,"SmoothDensity",Style["DistributionChart Type","Text",FontSize->16]},Append[ChartElementData["DistributionChart"],"BoxWhisker"]},
Initialization:>(data=Map[Length/@#&,Values[cuisineRecipes]])
];

(*tooltip content for GeoGraphics*)
locationTooltip[cuisine_]:=With[{recipes=Reverse@SortBy[Tally[Flatten[cuisineRecipes[cuisine]]],#[[2]]&]},
Grid[{
{Item[Style[cuisine<>" Recipes",Bold],Alignment->Center],SpanFromLeft},
{"Total Recipes:",Length[cuisineRecipes[cuisine]]},
{"Average Number of Ingredients:",IntegerPart[Mean[Length/@cuisineRecipes[cuisine]]]},

{Item[Histogram[Length/@cuisineRecipes[cuisine],Automatic,"PDF",FrameLabel->{"Number of Ingredients","Probability"},Frame->True,ImageSize->200],Alignment->Center],SpanFromLeft},
{Style["Top 8 ingredients",Bold],Null},
Sequence@@(Reverse[SortBy[Tally[Flatten[cuisineRecipes[cuisine]]],#[[2]]&]][[;;8]]/.
{a_,b_}:>{a,ToString[100*N[b/Length[Flatten@cuisineRecipes[cuisine]],2]]<>"%"})
},Frame->True,Alignment->Left,BaseStyle->{"Text",FontSize->14}]
]

(*GeoGraphics with tooltip*)
cuisineGeoGraphic[]:=Block[
{allEntities={EntityClass["Country","Africa"],EntityClass["Country","EastAsia"],EntityClass["Country","EasternEurope"],
EntityClass["Country","LatinAmerica"],EntityClass["Country","MiddleEast"],EntityClass["Country","NorthAmerica"],
EntityClass["Country","NorthernEurope"],EntityClass["Country","SouthAsia"],EntityClass["Country","SoutheastAsia"],
EntityClass["Country","SouthernEurope"],EntityClass["Country","WesternEurope"]},
geoRecipes
},
geoRecipes=GeoGraphics[
Flatten@MapThread[
{EdgeForm[Black],#3,
Tooltip[Polygon[#1],locationTooltip[#2]]}&,
{allEntities,cuisines,Table[ColorData["DarkRainbow"][i],{i,1/11,1,1/11}]}],
GeoBackground->GeoStyling["StreetMapNoLabels"],ImageSize->800
];
Legended[geoRecipes,SwatchLegend[Opacity[.5,#]&/@Table[ColorData["DarkRainbow"][i],{i,1/11,1,1/11}],cuisines]]]

(*Builds a graph connected ingredients used together in the specified cuisine*)
cuisineGraph[cuisine_]:=Block[
{
(*subsets connects all ingredients in a recipe to form a complete graph*)
connections=Flatten[Map[Subsets[#,{2}]&,cuisineRecipes[cuisine]],1]
},
(*Sort used to similarise {a,b} and {b,a} and then GatherBy used to remove duplicates*)
Graph[UndirectedEdge@@@(GatherBy[Sort/@connections,#&][[All,1]])]
]

(*Commented out code for exporting all graph as .wdx files for later use
Map[Export[#<>"Graph.wdx",cuisineGraph[#]]&,cuisines]*)

(*Build a subgraph containing all connected ingredients within a specified cuisine*)
ingrSubGraph[cuisine_,ingr_]:=Block[
{
graph=Import[FileNameJoin[{packageLocation,"data",cuisine<>"Graph.wdx"}]]
},
Subgraph[graph,_<->ingr|ingr<->_,VertexLabels->Placed["Name",Tooltip]]
]

(*Export data formatted for consumption by the R igraph package*)
exportNCOLFileForIngr[cuisine_,ingr_]:=Block[
{
graph=ingrSubGraph[cuisine,ingr],
edges
},
edges=List@@@EdgeList[graph];
Export[cuisine<>ingr<>"Edges.txt",StringJoin[edges/.{a_,b_}:>ToString[a]<>" "<>ToString[b]<>"\n"]]
]

(*find common ingredients*)
commonIngr[graph_]:=Block[
{
vDegree=VertexDegree[graph],
vMax,
vMin
},
vMax=VertexList[graph][[Flatten@Position[vDegree,Max[vDegree]]]];
vMin=VertexList[graph][[Flatten@Position[vDegree,Min[vDegree]]]];
{
{If[
Length[vMax]>1,"The most common ingredients are "<>StringJoin[Riffle[vMax,", "]]<>" each used with "<>ToString[Max[vDegree]]<>" other "<>If[Max[vDegree]==1,"ingredient","ingredients"],
"The most common ingredients is "<>vMax<>", used with "<>ToString[Max[vDegree]]<>" other "<>If[Max[vDegree]==1,"ingredient","ingredients"]
]},
{If[
Length[vMin]>1,"The least common ingredients are "<>StringJoin[Riffle[vMin,", "]]<>" each used with "<>ToString[Min[vDegree]]<>" other "<>If[Min[vDegree]==1,"ingredient","ingredients"],
"The least common ingredients is "<>vMin<>", used with "<>ToString[Min[vDegree]]<>" other "<>If[Min[vDegree]==1,"ingredient","ingredients"]
]}
}
]

(*Create a profile of the connectiveness of ingredients within a cuisine*)
cuisineIngrConnectivity[cuisine_]:=Block[
{
graph=Import[FileNameJoin[{packageLocation,"data",cuisine<>"Graph.wdx"}]]
},
Grid[{
Sequence@@commonIngr[graph],
{Histogram[VertexDegree[graph],Automatic,"PDF",ImageSize->400,Frame->True,FrameLabel->{"Connected Ingredients","Density"}],Show[Import@FileNameJoin[{packageLocation,"data",cuisine<>"CommGraph.wdx"}],ImageSize->360,AspectRatio->Automatic]}
},BaseStyle->{"Text",FontSize->14},Alignment->Left
]
]


End[]

EndPackage[]

