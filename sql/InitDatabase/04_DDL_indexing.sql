CREATE INDEX idx_assignment_history_agentid ON assignment_history (AgentID);
CREATE INDEX idx_assignment_history_assignmentid ON assignment_history (AssignmentID);
CREATE INDEX idx_bookings_assignmentid ON bookings (AssignmentID);
CREATE INDEX idx_space_travel_agents_email ON space_travel_agents (AgentID);