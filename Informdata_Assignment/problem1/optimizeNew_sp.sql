-- ######################################################################################################################################################
-- ## This is the stored procedure that you are trying to refactor to solve the performance issues that the legacy application is having.
-- ## Your goal is to minimize the fetch time and reduce any blocking. Any of these tables will have constant CRUD operations.
-- ######################################################################################################################################################


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[optimize_sp]
AS
BEGIN

-- Create temporary table #MaxStatusLog
SELECT  ID = MAX([Logs].pkLogID), SubjectID
INTO #MaxStatusLog
FROM  [OrderTracker]
    INNER JOIN [Orders] ON  [OrderTracker].fkOrderID = [Orders].pkOrderID
    INNER JOIN [Sessions] ON [OrderTracker].fkSessionID = [Sessions].pkSessionID
    INNER JOIN [Logs] ON [Logs].fkOrderID  = [OrderTracker].fkOrderID
WHERE  [Orders].fkOrderStatusID = 1  -- Index optimization on fkOrderStatusID
    AND [OrderTracker].[CompletionDate] IS NULL
    AND [Logs].[IsClientFacing] = 1
GROUP BY [OrderTracker].SubjectID;

-- Fetch data query
SELECT  [OrderTracker].SubjectID,
    Notes = MAX([Logs].Note),
    DateDue = MAX([Orders].[DueDate]),
    OrderStatus = LOWER([OrderStatus].StatusName)
FROM  [OrderTracker]
    INNER JOIN [Orders] ON [OrderTracker].fkOrderId = [Orders].pkOrderID
    INNER JOIN [Sessions] ON [OrderTracker].fkSessionID = [Sessions].pkSessionID
    INNER JOIN #MaxStatusLog m ON [OrderTracker].SubjectID = m.SubjectID
    INNER JOIN [Logs] ON [Logs].fkOrderId  = [OrderTracker].fkOrderId AND [Logs].pkLogID = m.ID
    INNER JOIN [OrderStatus] ON [OrderStatus].pkOrderStatusID = [Orders].fkOrderStatusID
WHERE  [Orders].fkOrderStatusID = 1
    AND [OrderTracker].[CompletionDate] IS NULL
    AND [Logs].[IsClientFacing] = 1
    AND [Logs].[DateSent] IS NULL
GROUP BY   [OrderTracker].SubjectID, [OrderStatus].StatusName
ORDER BY   [OrderTracker].SubjectID;

-- Update query
UPDATE [Logs]
SET DateSent  = GETDATE()
FROM [Logs] WITH (UPDLOCK, ROWLOCK)  -- Lock hints for reducing blocking
    INNER JOIN [OrderTracker] ON [Logs].fkOrderId  = [OrderTracker].fkOrderId
    INNER JOIN #MaxStatusLog l ON [Logs].pkLogID = l.ID
WHERE [Logs].DateSent IS NULL  
    AND [Logs].IsClientFacing = 1;

END
