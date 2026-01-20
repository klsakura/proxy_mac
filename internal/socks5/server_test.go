package socks5

import (
    "encoding/binary"
    "io"
    "net"
    "testing"

    "github.com/klsakura/proxy_mac/internal/rules"
)

func TestSOCKS5ConnectWithRule(t *testing.T) {
    echoLn, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil {
        t.Fatalf("listen: %v", err)
    }
    defer echoLn.Close()

    go func() {
        conn, _ := echoLn.Accept()
        if conn == nil {
            return
        }
        defer conn.Close()
        io.Copy(conn, conn)
    }()

    store := rules.NewStore([]rules.Rule{{Host: "api.dev.test", Upstream: "http://" + echoLn.Addr().String(), Enabled: true}})
    srv := NewServer(store)

    ln, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil {
        t.Fatalf("listen: %v", err)
    }
    defer ln.Close()

    go srv.Serve(ln)

    conn, err := net.Dial("tcp", ln.Addr().String())
    if err != nil {
        t.Fatalf("dial socks: %v", err)
    }
    defer conn.Close()

    // greeting: version 5, 1 method, no-auth (0x00)
    conn.Write([]byte{0x05, 0x01, 0x00})
    resp := make([]byte, 2)
    io.ReadFull(conn, resp)
    if resp[1] != 0x00 {
        t.Fatalf("expected no-auth accepted")
    }

    // connect request to api.dev.test:443
    host := []byte("api.dev.test")
    req := []byte{0x05, 0x01, 0x00, 0x03, byte(len(host))}
    req = append(req, host...)
    port := make([]byte, 2)
    binary.BigEndian.PutUint16(port, 443)
    req = append(req, port...)
    conn.Write(req)

    // reply
    reply := make([]byte, 10)
    io.ReadFull(conn, reply)
    if reply[1] != 0x00 {
        t.Fatalf("expected success reply")
    }

    // tunnel data
    conn.Write([]byte("ping"))
    buf := make([]byte, 4)
    io.ReadFull(conn, buf)
    if string(buf) != "ping" {
        t.Fatalf("unexpected echo: %q", string(buf))
    }
}
