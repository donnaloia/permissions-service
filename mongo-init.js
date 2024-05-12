db = db.getSiblingDB('admin');
// move to the admin db - always created in Mongo
db.auth("admin", "password");
// log as root admin if you decided to authenticate in your docker-compose file...
db = db.getSiblingDB('permissions');
// create and move to your new database
db.createUser({
'user': "admin",
'pwd': "password",
'roles': [{
    'role': 'dbOwner',
    'db': 'permissions'}]});
// user created