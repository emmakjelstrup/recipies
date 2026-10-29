package io.github.emmakjelstrup.cookbook.common.web;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/**
 * Turns every exception thrown by a controller into an RFC 7807 {@link ProblemDetail} response.
 *
 * <p>{@link ResponseEntityExceptionHandler} already maps Spring MVC's own exceptions (unknown route,
 * unsupported method, unreadable body, validation errors) to {@code ProblemDetail}. This class adds a
 * fallback for everything else, so clients always get the same {@code application/problem+json} shape.
 */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(Exception.class)
    ProblemDetail handleUnexpected(Exception ex) {
        // Log the details for us, but never send exception messages or stack traces to the client.
        log.error("Unhandled exception", ex);
        return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred.");
    }
}
