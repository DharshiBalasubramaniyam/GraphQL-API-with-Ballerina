import ballerina/graphql;
import ballerina/http;
import ballerinax/mongodb;
import ballerina/uuid;

configurable string host = "localhost";
configurable int port = 27017;

mongodb:Client mongoDB = check new (config = {
    connection: {
        serverAddress: {
            host: host,
            port: port
        }
    }
});

type Book record {|
    readonly string id;
    *BookRequest;
|};

type BookRequest record {|
    string name;
    string author;
    int year;
|};

type NotFoundIdError record {|
    *http:NotFound;
    string body;
|};

listener graphql:Listener bookListener = new (9090);

service /graphql on bookListener {

    private final mongodb:Database booksDb;

    function init() returns error? {
        self.booksDb = check mongoDB->getDatabase("sample");
    }

    resource function get books() returns Book[]|error {
        mongodb:Collection books = check self.booksDb->getCollection("books");

        stream<Book, error?> findResult = check books->find();

        return from Book b in findResult
            select b;

    }

    resource function get book(string id = "") returns Book|error{

        if id == "" {
            return error("Id is required!");
        }

        mongodb:Collection books = check self.booksDb->getCollection("books");

        Book|mongodb:DatabaseError|mongodb:ApplicationError|error? findResult = check books->findOne({id});

        if findResult is () {
            return error("Id not found => " + id);
        }

        return findResult;
        
    }

    remote function addNewBook(BookRequest bookRequest) returns Book|error {

        mongodb:Collection books = check self.booksDb->getCollection("books");

        string id = uuid:createType1AsString();
        Book newBook = {id, ...bookRequest};

        check books->insertOne(newBook);

        return newBook;
        
    }

    remote function updateBook(BookRequest bookRequest, string id = "") returns Book|error {

        if id == "" {
            return error("Id is required!");
        }

        mongodb:Collection books = check self.booksDb->getCollection("books");

        mongodb:UpdateResult updateResult = check books->updateOne({id}, {set: bookRequest});

        if updateResult.modifiedCount != 1 {
            return error("Id not found => " + id);
        }

        return {id, ...bookRequest};
    }

    remote function deleteBook(string id = "") returns string|error {

        if id == "" {
            return error("Id is required!");
        }

        mongodb:Collection books = check self.booksDb->getCollection("books");

        mongodb:DeleteResult deleteResult = check books->deleteOne({id});

        if (deleteResult.deletedCount != 1) {
            return error("Id not found => " + id);
        }

        return id;
    }

}

