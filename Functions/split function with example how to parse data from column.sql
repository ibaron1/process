USE [master]
GO

create Function SplitString
	(@List Varchar(Max), @Delimiter Char(1))
Returns @Items 
Table (Item Varchar(100))
As
Begin
 Declare @Item Varchar(100), @Pos TinyInt
 While Len(@List) > 0 
 Begin
 Set @Pos = CharIndex(@Delimiter, @List)
 If @Pos = 0 Set @Pos = Len(@List) + 1 
 Set @Item = Left(@List, @Pos - 1)
 Insert @Items 
 Select Ltrim(Rtrim(@Item))
 Set @List = 
     SubString(@List, @Pos + case when @Delimiter=' ' then 1 else Len(@Delimiter) end, Len(@List))

 End
 Return
End

Go


Declare @myTable Table (CustomerId Int, CustomerName Varchar(20))
Insert Into @myTable 
Select 1, 'CustA' Union All 
Select 2, 'CustB' Union All 
Select 3, 'CustC'

Declare @CustomerIdList Varchar(200)
Set @CustomerIdList = '1, 3'

Select * 
From 
	@myTable As MainTable
	Cross Apply (Select * From master..SplitString(@CustomerIdList, ',')) As CustListSplit 
Where 
	MainTable.CustomerId = CustListSplit.Item 




