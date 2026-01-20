package socks5

import (
    "encoding/binary"
    "io"
    "net"
    "net/url"
    "strconv"
    "strings"

    "github.com/klsakura/proxy_mac/internal/rules"
)

type Server struct {
    store *rules.Store
}

func NewServer(store *rules.Store) *Server {
    return &Server{store: store}
}

func (s *Server) Serve(ln net.Listener) error {
    for {
        conn, err := ln.Accept()
        if err != nil {
            return err
        }
        go s.handleConn(conn)
    }
}

func (s *Server) handleConn(conn net.Conn) {
    defer conn.Close()

    buf := make([]byte, 2)
    if _, err := io.ReadFull(conn, buf); err != nil {
        return
    }
    if buf[0] != 0x05 {
        return
    }
    nMethods := int(buf[1])
    methods := make([]byte, nMethods)
    if _, err := io.ReadFull(conn, methods); err != nil {
        return
    }
    conn.Write([]byte{0x05, 0x00})

    header := make([]byte, 4)
    if _, err := io.ReadFull(conn, header); err != nil {
        return
    }
    if header[0] != 0x05 || header[1] != 0x01 {
        return
    }

    dest, err := readAddr(conn, header[3])
    if err != nil {
        return
    }

    hostOnly := dest
    if h, _, err := net.SplitHostPort(dest); err == nil {
        hostOnly = h
    }
    dialAddr := dest
    if rule, ok := rules.MatchHost(s.store.Snapshot(), hostOnly); ok {
        if u, err := url.Parse(rule.Upstream); err == nil {
            dialAddr = hostPort(u)
        }
    }

    upstream, err := net.Dial("tcp", dialAddr)
    if err != nil {
        conn.Write([]byte{0x05, 0x01, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
        return
    }
    defer upstream.Close()

    conn.Write([]byte{0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
    go io.Copy(upstream, conn)
    io.Copy(conn, upstream)
}

func readAddr(r io.Reader, atyp byte) (string, error) {
    switch atyp {
    case 0x01:
        ip := make([]byte, 4)
        if _, err := io.ReadFull(r, ip); err != nil {
            return "", err
        }
        port := make([]byte, 2)
        if _, err := io.ReadFull(r, port); err != nil {
            return "", err
        }
        return net.JoinHostPort(net.IP(ip).String(), portString(port)), nil
    case 0x03:
        lenb := make([]byte, 1)
        if _, err := io.ReadFull(r, lenb); err != nil {
            return "", err
        }
        host := make([]byte, int(lenb[0]))
        if _, err := io.ReadFull(r, host); err != nil {
            return "", err
        }
        port := make([]byte, 2)
        if _, err := io.ReadFull(r, port); err != nil {
            return "", err
        }
        return net.JoinHostPort(string(host), portString(port)), nil
    case 0x04:
        ip := make([]byte, 16)
        if _, err := io.ReadFull(r, ip); err != nil {
            return "", err
        }
        port := make([]byte, 2)
        if _, err := io.ReadFull(r, port); err != nil {
            return "", err
        }
        return net.JoinHostPort(net.IP(ip).String(), portString(port)), nil
    default:
        return "", io.ErrUnexpectedEOF
    }
}

func portString(b []byte) string {
    return strconv.Itoa(int(binary.BigEndian.Uint16(b)))
}

func hostPort(u *url.URL) string {
    host := u.Host
    if !strings.Contains(host, ":") {
        if u.Scheme == "https" {
            host = host + ":443"
        } else {
            host = host + ":80"
        }
    }
    return host
}
