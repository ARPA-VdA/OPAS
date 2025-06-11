-- +----------------------------------------------------------------------------------------------+
-- | - Script Name   : db_creation.sql                                                            |
-- | - Author        : Ecometer s.n.c.                                                            |
-- | - Creation Date : 2025-03-31                                                                 |
-- | - Description   : Script to create PostgreSQL database, groups and roles.                    |
-- +----------------------------------------------------------------------------------------------+


-- ------------------------------------------------------------------------------------------------
--  CREATE A NEW GROUP ROLES
-- ------------------------------------------------------------------------------------------------
-- Typically a role being used as a group would not have the LOGIN attribute, though you can set it if you wish.
CREATE ROLE group_admin NOINHERIT VALID UNTIL 'infinity';
COMMENT ON ROLE group_admin IS 'Main db admin group';

CREATE ROLE group_bobo NOINHERIT VALID UNTIL 'infinity';
COMMENT ON ROLE group_bobo IS 'Bobo web site admin group';

CREATE ROLE group_readonly NOINHERIT VALID UNTIL 'infinity';
COMMENT ON ROLE group_readonly IS 'Main web site read-only group';

CREATE ROLE group_tools NOINHERIT VALID UNTIL 'infinity';
COMMENT ON ROLE group_tools IS 'Main web site tools group';


-- ------------------------------------------------------------------------------------------------
--  CREATE A FEW NEW ROLES
-- ------------------------------------------------------------------------------------------------
CREATE USER user_admin WITH PASSWORD 'xxxxxxxxxx' IN ROLE group_admin NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE;
COMMENT ON ROLE user_admin IS 'Main web site admin user';

CREATE USER user_bobo WITH PASSWORD 'xxxxxxxxxx' IN ROLE group_bobo NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE;
COMMENT ON ROLE user_bobo IS 'Bobo web site admin user';

CREATE USER user_readonly WITH PASSWORD 'xxxxxxxxxx' IN ROLE group_readonly NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE;
COMMENT ON ROLE user_readonly IS 'Main web site read-only user';

CREATE USER user_tools WITH PASSWORD 'xxxxxxxxxx' IN ROLE group_tools NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE;
COMMENT ON ROLE user_tools IS 'Main web site tools user';

CREATE USER user_api WITH PASSWORD 'xxxxxxxxxx' IN ROLE group_tools NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE;
COMMENT ON ROLE user_api IS 'Main api user';

CREATE ROLE group_clients_ro NOINHERIT VALID UNTIL 'infinity';
COMMENT ON ROLE group_clients_ro IS 'This group contains users/clients thant can read metadata schema';

-- Creato appositamente senza permessi sugli altri trigger al fine di non farli scattare
CREATE ROLE user_swam WITH
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT
    NOLOGIN
    NOREPLICATION
    NOBYPASSRLS;
GRANT user_swam TO user_tools;


-- ------------------------------------------------------------------------------------------------
-- CREATE A BRAND NEW DATABASE
-- ------------------------------------------------------------------------------------------------
--DROP DATABASE IF EXISTS opas;
CREATE DATABASE opas WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    --LC_COLLATE = 'it_IT.UTF-8'
    --LC_CTYPE = 'it_IT.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- grants
GRANT ALL ON DATABASE opas TO postgres;
GRANT ALL ON DATABASE opas TO GROUP group_admin;
GRANT CONNECT ON DATABASE opas TO GROUP group_bobo;
GRANT CONNECT ON DATABASE opas TO GROUP group_readonly;
GRANT CONNECT ON DATABASE opas TO GROUP group_tools;

-- comment
COMMENT ON DATABASE opas IS 'Database CLOUD per progetto OPAS';


-- ------------------------------------------------------------------------------------------------
-- CONNECT TO NEW DATABASE
-- ------------------------------------------------------------------------------------------------
