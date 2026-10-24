package interceptor

import (
	"context"

	"connectrpc.com/connect/v2"
	"connectrpc.com/connect/v2/connectproto"
	"google.golang.org/genproto/googleapis/rpc/errdetails"
	"splajompy.com/api/v2/internal/middleware"
	"splajompy.com/api/v2/internal/utilities"
)

func AppVersion(next connect.ServerFunc) connect.ServerFunc {
	return func(ctx context.Context, spec connect.Spec, stream connect.ServerStream) error {
		info, _ := connect.CallInfoForServerContext(ctx)
		ctx = middleware.WithAppVersion(ctx, info.RequestHeader().Get("X-App-Version"))
		if !utilities.IsAppUpdatedToVersion(ctx, middleware.MinimumAppVersion) {
			err := connect.NewError(connect.CodeFailedPrecondition, middleware.AppUpgradeMessage)
			if detail, detailErr := connectproto.NewErrorDetail(&errdetails.ErrorInfo{
				Reason:   "APP_UPGRADE_REQUIRED",
				Domain:   "splajompy.com",
				Metadata: map[string]string{"minimumAppVersion": middleware.MinimumAppVersion},
			}); detailErr == nil {
				err = err.WithDetail(detail)
			}
			return err
		}
		return next(ctx, spec, stream)
	}
}
