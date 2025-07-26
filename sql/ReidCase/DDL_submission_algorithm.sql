CREATE INDEX idx_assignment_history_agentid ON assignment_history (AgentID);
CREATE INDEX idx_assignment_history_assignmentid ON assignment_history (AssignmentID);
CREATE INDEX idx_bookings_assignmentid ON bookings (AssignmentID);
CREATE INDEX idx_space_travel_agents_email ON space_travel_agents (AgentID);

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

DROP PROCEDURE IF EXISTS GetAgentContextScores;
DELIMITER // 
CREATE PROCEDURE GetAgentContextScores(
    IN p_customer_name VARCHAR(255),
    IN p_destination VARCHAR(255),
    IN p_launch_location VARCHAR(255),
    IN p_lead_source VARCHAR(255),
    IN p_communication_method VARCHAR(255)
) BEGIN IF p_customer_name IS NULL
OR p_customer_name = '' THEN SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Customer name is required';
END IF;
IF p_destination IS NULL
OR p_destination = '' THEN SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Destination is required';
END IF;
IF p_launch_location IS NULL
OR p_launch_location = '' THEN SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Launch location is required';
END IF;
IF p_lead_source IS NULL
OR p_lead_source = '' THEN SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Lead source is required';
END IF;
IF p_communication_method IS NULL
OR p_communication_method = '' THEN SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Communication method is required';
END IF;
WITH CustomerHistory AS (
    SELECT ah.AgentID,
        ah.CustomerName,
        SUM(
            CASE
                WHEN b.CancelledDate IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT b.BookingID) AS CustomerSuccessRate
    FROM assignment_history AS ah
        LEFT JOIN bookings AS b ON ah.AssignmentID = b.AssignmentID
    WHERE (
            LOWER(ah.CustomerName) LIKE CONCAT('%', LOWER(p_customer_name), '%')
            OR SOUNDEX(ah.CustomerName) = SOUNDEX(p_customer_name)
        )
    GROUP BY ah.AgentID,
        ah.CustomerName
    HAVING CustomerSuccessRate IS NOT NULL
),
DestinationHistory AS (
    SELECT ah.AgentID,
        b.Destination,
        SUM(
            CASE
                WHEN b.CancelledDate IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT b.BookingID) AS DestinationSuccessRate
    FROM bookings AS b
        LEFT JOIN assignment_history AS ah ON ah.AssignmentID = b.AssignmentID
    WHERE (
            LOWER(b.Destination) LIKE CONCAT('%', LOWER(p_destination), '%')
            OR SOUNDEX(b.Destination) = SOUNDEX(p_destination)
        )
    GROUP BY ah.AgentID,
        b.Destination
    HAVING DestinationSuccessRate IS NOT NULL
),
PackageHistory AS (
    SELECT ah.AgentID,
        b.Package,
        SUM(
            CASE
                WHEN b.CancelledDate IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT b.BookingID) AS PackageSuccessRate
    FROM bookings AS b
        LEFT JOIN assignment_history AS ah ON ah.AssignmentID = b.AssignmentID
    GROUP BY ah.AgentID,
        b.Package
    HAVING PackageSuccessRate IS NOT NULL
),
LaunchHistory AS (
    SELECT ah.AgentID,
        b.LaunchLocation,
        SUM(
            CASE
                WHEN b.CancelledDate IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT b.BookingID) AS LaunchSuccessRate
    FROM bookings AS b
        LEFT JOIN assignment_history AS ah ON ah.AssignmentID = b.AssignmentID
    WHERE (
            LOWER(b.LaunchLocation) LIKE CONCAT('%', LOWER(p_launch_location), '%')
            OR SOUNDEX(b.LaunchLocation) = SOUNDEX(p_launch_location)
        )
    GROUP BY ah.AgentID,
        b.LaunchLocation
    HAVING LaunchSuccessRate IS NOT NULL
),
LeadSourceHistory AS (
    SELECT ah.AgentID,
        ah.LeadSource,
        SUM(
            CASE
                WHEN b.CancelledDate IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT b.BookingID) AS LeadSuccessRate
    FROM bookings AS b
        LEFT JOIN assignment_history AS ah ON ah.AssignmentID = b.AssignmentID
    WHERE (
            LOWER(ah.LeadSource) LIKE CONCAT('%', LOWER(p_lead_source), '%')
            OR SOUNDEX(ah.LeadSource) = SOUNDEX(p_lead_source)
        )
    GROUP BY ah.AgentID,
        ah.LeadSource
    HAVING LeadSuccessRate IS NOT NULL
),
CommunicationHistory AS (
    SELECT ah.AgentID,
        ah.CommunicationMethod,
        SUM(
            CASE
                WHEN b.CancelledDate IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT b.BookingID) AS CommunicationSuccessRate
    FROM assignment_history AS ah
        LEFT JOIN bookings AS b ON ah.AssignmentID = b.AssignmentID
    WHERE (
            LOWER(ah.CommunicationMethod) LIKE CONCAT('%', LOWER(p_communication_method), '%')
            OR SOUNDEX(ah.CommunicationMethod) = SOUNDEX(p_communication_method)
        )
    GROUP BY ah.AgentID,
        ah.CommunicationMethod
    HAVING CommunicationSuccessRate IS NOT NULL
),
AgentPackageRevenue AS (
    SELECT a.AgentID,
        SUM(b.PackageRevenue) AS PackageRevenue
    FROM space_travel_agents AS a
        INNER JOIN assignment_history AS ah ON a.AgentID = ah.AgentID
        INNER JOIN bookings AS b ON ah.AssignmentID = b.AssignmentID
    GROUP BY a.AgentID
),
MinMaxPackageRatings AS (
    SELECT MIN(PackageRevenue) AS min_rating,
        MAX(PackageRevenue) AS max_rating
    FROM AgentPackageRevenue
),
NormalizedPackageRatings AS (
    SELECT AgentID,
        CASE
            WHEN mm.max_rating = mm.min_rating THEN 1
            ELSE (PackageRevenue - mm.min_rating) / (mm.max_rating - mm.min_rating)
        END AS NormalizedPackageRating
    FROM AgentPackageRevenue,
        MinMaxPackageRatings mm
)
SELECT (
        COALESCE(abm.NormBaseAgentScore, 0) + COALESCE(pr.NormalizedPackageRating, 0) + COALESCE(ch.CustomerSuccessRate, 0) + COALESCE(dh.DestinationSuccessRate, 0) + COALESCE(lh.LaunchSuccessRate, 0) + COALESCE(lsh.LeadSuccessRate, 0) + COALESCE(cch.CommunicationSuccessRate, 0)
    ) / 7 AS AgentScore,
    a.*
FROM space_travel_agents AS a
    LEFT JOIN CustomerHistory AS ch ON a.AgentID = ch.AgentID
    LEFT JOIN DestinationHistory AS dh ON a.AgentID = dh.AgentID
    LEFT JOIN LaunchHistory AS lh ON a.AgentID = lh.AgentID
    LEFT JOIN LeadSourceHistory AS lsh ON a.AgentID = lsh.AgentID
    LEFT JOIN CommunicationHistory AS cch ON a.AgentID = cch.AgentID
    LEFT JOIN NormalizedPackageRatings AS pr ON a.AgentID = pr.AgentID
    LEFT JOIN agent_base_metrics AS abm ON a.AgentID = abm.AgentID
ORDER BY AgentScore DESC;
END // 
DELIMITER;