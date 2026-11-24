Problem statement:
It is a challenge for an AWS Solutions Architect to know what is wrong and what may be wrong within a running database on customer environment. 
Avoiding a database issue is better than fixing a running database issue. Hence, checking database best practices whenever possible is preferable. 

The target database engine to check are:
(1) SQL Server, with working directory at 'mssql'
(2) MySQL, with working directory at 'mysql'
(3) Oracle, with working directory at 'oracle'
(4) PostgreSQL, with working directory at 'pgsql'
(5) MongoDB, with working directory at 'mongodb'

The behavior of the database best practices checker script is as follow:
- the checker is a script or a command-line executable (CLI)
- the script name is dbbpc, with file extension added based on the language used for the script creation (e.g. .py for Python, .exe for Windows)
- the script being called with parameters as follow:
a. database engine type (parameter: dbengine)
b. database hostname (parameter: dbhost)
c. database port number (parameter: port)
d. database username (parameter: username)
e. database password (parameter: password). If password parameter is not given, ask for it with this kind of prompt: "give me password to access the database: "
f. directory usage:
    * if the database engine is 'mongodb' use SQL scripts located on 'mongodb' directory
    * if the database engine is 'mssql' use SQL scripts located on 'mssql' directory
    * if the database engine is 'mssql' use SQL scripts located on 'mssql' directory
    * if the database engine is 'mysql' use SQL scripts located on 'mysql' directory
    * if the database engine is 'oracle' use SQL scripts located on 'oracle' directory
    * if the database engine is 'postgres' use SQL scripts located on 'pgsql' directory
g. The rules for database best practices is defined on a Markdown file named 'bestpractices.md'. Run the SQL scripts found there and write the output to HTML file named 'dbbpc.html'.

Workflow:
Script being called/run -> Get parameter -> Connect to the database instance -> Run relevant SQL scripts -> Write output as HTML file for analysis by AWS SA.  

You are being tasked to plan a build of this database best practices checker script. 

The target language are: 
(1) Python for ability to run as a script downloaded from Github
(2) VB.net for ability to run as an executable in Windows
(3) C#.net for ability to run as an executable in Amazon Linux 

Task:
1. Create scripts on each database engine directories based on each database best practices rules as defined on a Markdown file named 'bestpractices.md'. 
2. Create a detailed specification of the script.
3. Create a ready to run script for Python and ready to compile and run for VB.net and C#.net. 