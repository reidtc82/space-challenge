# space-challenge

**Algorithm Challenge**
***Submission***
***Reid Case***
***07/25/2025***

Submission is contained in ./sql/ReidCase/ as a single file called DDL_submission_algorithm.sql. This file only contains DDL to establish indexes, create a view, and create a stored procedure as requested. Syntax is compliant with MySQL deduced from the provided .txt files with DDL to set up the database tables and perform inserts. 

The stored procedure takes the requested paramters and produces a list of all Agents sorted by the calculated score. 

Additional folders were for extended development and analysis. 

./frontend/ can be ignored as this is an unexplored direction to standup a basic interface to exepriment with the algorithm. For the sake of time this was not explored further.

./notebooks/ contains a Jupyter Notebook that was used to do some basic exploration of the data provided.

There is a docker-compose file that can be run using basic command $docker-compose up --build assuming docker is installed and running on the host machine. A .env file will need to be created and the following contents filled in:

MYSQL_ROOT_PASSWORD=whateverrootpasswordyouwant
MYSQL_DATABASE=whateveryouwanttonamethedatabase
MYSQL_USER=someuserforit
MYSQL_PASSWORD=andapasswrodforthatuser

The docker-compose file will take care of the rest. It will use the sql in ./sql/InitDatabase/ to set up the database and create the other assets. 

Otherwise just use you own systems and make use of the file in ./sql/ReidCase/.

***Algorithm***
After some basic exploratory data analysis I settled on a simple approach. My algorthm has two major components; a base score and a score specific to the data submitted for the specific hypotehtical trip order.

There was little correlation between the variables and revenue was often skewed. 

The base side of the algorithm calculates a measure of efficiency in terms of revenue over elapsed time, a success rate through total bookings complete over all booking attempted, and the average customer score rating. These are normalized thorugh min-max and then averaged. 

The specific scoring side of the algorithm calculates the average normalized ratings for the destination, communication type, launch location, customer, lead, and normalized revenue of packages for each agent. These are averaged with the base score. The output is sorted highest to lowest. 