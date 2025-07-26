CREATE OR REPLACE VIEW agent_base_metrics AS WITH BaseAgentMetrics AS (
        SELECT a.AgentID,
            a.AverageCustomerServiceRating,
            SUM(b.PackageRevenue) / NULLIF(
                SUM(
                    CASE
                        WHEN b.BookingCompleteDate IS NOT NULL
                        OR b.CancelledDate IS NOT NULL THEN TIMESTAMPDIFF(
                            SECOND,
                            ah.AssignedDateTime,
                            COALESCE(b.BookingCompleteDate, b.CancelledDate)
                        ) / 3600
                        ELSE 0
                    END
                ),
                0
            ) AS AverageRevenuePerHour,
            SUM(
                CASE
                    WHEN b.BookingCompleteDate IS NOT NULL THEN 1
                    ELSE 0
                END
            ) / NULLIF(COUNT(DISTINCT b.BookingID), 0) AS BookingSuccessRate
        FROM space_travel_agents a
            LEFT JOIN assignment_history ah ON a.AgentID = ah.AgentID
            LEFT JOIN bookings b ON ah.AssignmentID = b.AssignmentID
        GROUP BY a.AgentID
    ),
    NormalizedAgentBaseMetrics AS (
        SELECT *,
            (
                AverageRevenuePerHour - MIN(AverageRevenuePerHour) OVER()
            ) / NULLIF(
                MAX(AverageRevenuePerHour) OVER() - MIN(AverageRevenuePerHour) OVER(),
                0
            ) AS NormRevenuePerHour,
            (
                BookingSuccessRate - MIN(BookingSuccessRate) OVER()
            ) / NULLIF(
                MAX(BookingSuccessRate) OVER() - MIN(BookingSuccessRate) OVER(),
                0
            ) AS NormSuccessRate,
            (
                AverageCustomerServiceRating - MIN(AverageCustomerServiceRating) OVER()
            ) / NULLIF(
                MAX(AverageCustomerServiceRating) OVER() - MIN(AverageCustomerServiceRating) OVER(),
                0
            ) AS NormRating
        FROM BaseAgentMetrics
    )
SELECT AgentID,
    (
        COALESCE(NormRevenuePerHour, 0) + COALESCE(NormSuccessRate, 0) + COALESCE(NormRating, 0)
    ) / 3 AS NormBaseAgentScore
FROM NormalizedAgentBaseMetrics;