db = db.getSiblingDB('admin');
// move to the admin db - always created in Mongo
db.auth(process.env.DB_USER, process.env.DB_PASSWORD);
// log as root admin if you decided to authenticate in your docker-compose file...
db = db.getSiblingDB(DB_COLLECTION);
// create and move to your new database
db.createUser({
'user': process.env.DB_USER,
'pwd': process.env.DB_PASSWORD,
'roles': [{
    'role': 'dbOwner',
    'db': DB_COLLECTION}]});
// user created