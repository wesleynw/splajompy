package interceptor

import (
	"context"

	"connectrpc.com/connect/v2"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/utilities"
)

func AppVersion(next connect.ServerFunc) connect.ServerFunc {
	return func(ctx context.Context, spec connect.Spec, stream connect.ServerStream) error {
		info, _ := connect.CallInfoForServerContext(ctx)
		ctx = middleware.WithAppVersion(ctx, info.RequestHeader().Get("X-App-Version"))
		if !utilities.IsAppUpdatedToVersion(ctx, middleware.MinimumAppVersion) {
			info.ResponseHeader().Set("X-Minimum-App-Version", middleware.MinimumAppVersion)
			return connect.NewError(connect.CodeFailedPrecondition, middleware.AppUpgradeMessage)
		}
		return next(ctx, spec, stream)
	}
}
