package interceptor_test

import (
	"context"
	"testing"

	"connectrpc.com/connect/v2"
	"github.com/stretchr/testify/require"
	"splajompy.com/api/v2/internal/interceptor"
)

func TestAuthPublicProcedures(t *testing.T) {
	const public = "/test.AuthService/Login"
	const protected = "/test.AuthService/Profile"
	called := false
	server := connect.NewServer(interceptor.AppVersion, interceptor.Auth(nil, public))
	for _, procedure := range []string{public, protected, public + "Extra"} {
		server.Register(connect.Method{
			Spec: connect.Spec{Procedure: procedure, StreamType: connect.StreamTypeUnary},
			Handler: func(context.Context, connect.Spec, connect.ServerStream) error {
				called = true
				return nil
			},
		})
	}
	for _, tc := range []struct {
		name, procedure, authorization, version string
		code                                    connect.Code
	}{
		{name: "public without session", procedure: public},
		{name: "public with invalid authorization", procedure: public, authorization: "Basic token"},
		{name: "public with old app version", procedure: public, version: "1.8.0", code: connect.CodeFailedPrecondition},
		{name: "protected without session", procedure: protected, code: connect.CodeUnauthenticated},
		{name: "public prefix remains protected", procedure: public + "Extra", code: connect.CodeUnauthenticated},
	} {
		t.Run(tc.name, func(t *testing.T) {
			called = false
			info := &connect.CallInfo{}
			info.RequestHeader().Set("Authorization", tc.authorization)
			info.RequestHeader().Set("X-App-Version", tc.version)
			err := server.Call(t.Context(), tc.procedure, info, nil)
			if tc.code == 0 {
				require.NoError(t, err)
			} else {
				require.Equal(t, tc.code, connect.CodeOf(err))
			}
			require.Equal(t, tc.code == 0, called)
		})
	}
}
