package interceptor

import (
	"context"
	"net/http"
	"slices"

	"connectrpc.com/connect/v2"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/middleware"
)

func Auth(q *queries.Queries, publicProcedures ...string) connect.ServerInterceptor {
	return func(next connect.ServerFunc) connect.ServerFunc {
		return func(ctx context.Context, spec connect.Spec, stream connect.ServerStream) error {
			if slices.Contains(publicProcedures, spec.Procedure) {
				return next(ctx, spec, stream)
			}
			info, _ := connect.CallInfoForServerContext(ctx)
			authenticatedCtx, err := middleware.Authenticate(ctx, q, info.RequestHeader().Get("Authorization"))
			if err != nil {
				if ctxErr := ctx.Err(); ctxErr != nil {
					return ctxErr
				}
				code, message := connect.CodeInternal, http.StatusText(http.StatusInternalServerError)
				switch err.Status {
				case http.StatusBadRequest:
					code, message = connect.CodeInvalidArgument, err.Error()
				case http.StatusUnauthorized:
					code, message = connect.CodeUnauthenticated, err.Error()
				}
				return connect.NewError(code, message)
			}
			return next(authenticatedCtx, spec, stream)
		}
	}
}
