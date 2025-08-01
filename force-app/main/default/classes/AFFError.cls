/**
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * @descrption This class is used to help working with Exceptions
 */
public inherited sharing abstract class AFFError {

    public inherited sharing class DmlError {
        public Integer recordIndex;
        public String statusCode;
        public String statusMessage;
        public List<String> fields;
    }

    public inherited sharing class SerializableError {

        public String message;
        public String stackTrace;
        public Integer lineNumber;
        public String type;
        public List<DmlError> dmlErrors;
        public SerializableError cause;

    /**
     * @description Serializes this object instance into a pretty-formatted JSON string.
     * @return A JSON string representing the exception details.
     */
    public String serialize() {
        return JSON.serializePretty(this);
    }
    } 

    /**
     * @description Marshals a live Exception object into a SerializableError instance.
     * This is the primary method for converting a caught exception.
     * @param e The exception to convert.
     * @return A new instance of SerializableError representing the error chain.
     */
    public static SerializableError marshal(Exception e) {
        if (e == null) {
            return null;
        }

        SerializableError result = new SerializableError();
        result.type = e.getTypeName();
        result.message = e.getMessage();
        result.stackTrace = e.getStackTraceString();

        // Specifically handle DML exceptions to extract field-level details
        if (e instanceof DmlException) {
            result.dmlErrors = marshalDmlErrors((DmlException) e);
        }

        // Recursively marshal the cause of the exception
        if (e.getCause() != null) {
            result.cause = marshal(e.getCause());
        }

        return result;
    }

    /**
     * @description Parses a JSON string back into a SerializableError object graph.
     * @param jsonString The JSON string, typically from logs or an API response.
     * @return A SerializableError instance.
     */
    public static SerializableError parse(String jsonString) {
        return (SerializableError) JSON.deserialize(jsonString, SerializableError.class);
    }

    /**
     * @description Private helper to convert DmlException details into DmlError objects.
     */
    private static List<DmlError> marshalDmlErrors(DmlException dmlEx) {
        List<DmlError> errors = new List<DmlError>();
        for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
            DmlError detail = new DmlError();
            detail.recordIndex = i;
            detail.statusCode = dmlEx.getDmlStatusCode(i);
            detail.statusMessage = dmlEx.getDmlMessage(i);
            detail.fields = dmlEx.getDmlFieldNames(i);
            errors.add(detail);
        }
        return errors;
    }
}