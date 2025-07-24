-- Prototype: Stack-rank agents for a new booking based on historical revenue and ratings
-- Inputs (to be parameterized in a procedure):
--   @comm_method, @lead_source, @destination, @launch_location

SELECT 
  a.AgentID,
  a.FirstName,
  a.LastName,
  a.AverageCustomerServiceRating,
  IFNULL(SUM(b.TotalRevenue), 0) AS TotalRevenue,
  COUNT(DISTINCT ah.AssignmentID) AS NumAssignments,
  -- Simple score: revenue + (rating * 10000)
  IFNULL(SUM(b.TotalRevenue), 0) + (a.AverageCustomerServiceRating * 10000) AS AgentScore
FROM space_travel_agents a
LEFT JOIN assignment_history ah ON a.AgentID = ah.AgentID
LEFT JOIN bookings b ON ah.AssignmentID = b.AssignmentID
  AND b.Destination = 'Mars' -- Example input
  AND b.LaunchLocation = 'Dallas-Fort Worth Launch Complex' -- Example input
  AND ah.CommunicationMethod = 'Phone Call' -- Example input
  AND ah.LeadSource = 'Organic' -- Example input
GROUP BY a.AgentID
ORDER BY AgentScore DESC;
