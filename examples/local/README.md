# Local example

Applies circuit-sqlite to a throwaway Rocky Linux 10 container with systemd, installing SQLite and creating `/var/lib/example/app.db`, owned by `daemon`, and `/srv/example/root.db`, owned by root. You need Conn3x and Podman.

```sh
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` To see it working:

```sh
ssh -p 2338 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 'sqlite3 /var/lib/example/app.db "SELECT 1;"'
```

`up.sh` listens on `127.0.0.1:2338`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` stops the container, which removes it, and deletes the key and the state.
