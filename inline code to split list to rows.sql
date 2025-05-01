-- Sample table
CREATE TABLE Orders (
    OrderID INT,
    ItemList VARCHAR(MAX)
);

-- Sample data
INSERT INTO Orders (OrderID, ItemList)
VALUES
(1, 'Apple,Banana,Cherry'),
(2, 'Orange,Lemon'),
(3, 'Mango');

SELECT 
    o.OrderID,
    Items.id AS ItemNumber,
    Items.Item
FROM Orders o
CROSS APPLY (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS id,
        x.value('.', 'VARCHAR(896)') AS Item
    FROM (
        SELECT CAST('<x>' + REPLACE(o.ItemList, ',', '</x><x>') + '</x>' AS XML) AS SplitXml
    ) AS xmlData
    CROSS APPLY xmlData.SplitXml.nodes('/x') AS Split(x)
) AS Items;

