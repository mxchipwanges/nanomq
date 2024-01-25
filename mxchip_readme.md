# MXCHIP Modify for AO-SGW7000

- 2024.01.25
- For MQTT client disconnect notify issue for AO SGW7000.

## Build nanomq
* Use github workflow for the final release to keep the same configurations with official release.
* For local test, just follow the steps bellow.

### Install mbedTLS
```bash
git clone https://github.com/Mbed-TLS/mbedtls.git
cd mbedtls
cmake .
make -j4
sudo make install
```

### Rebuild
```bash
# build dir
cd nanomq
mkdir build
cd build

# cmake
#cmake -DDEBUG=ON -DNNG_ENABLE_TLS=ON -DCONFIG_MXCHIP_DEBUG=1 ..
cmake -DDEBUG=ON -DNNG_ENABLE_TLS=ON ..
make -j4

# output
ls -al nanomq/nanomq
```

## Run
```bash
./nanomq start
# or
./nanomq start --conf <your config file>
```

## Client connection
* Use `MQTTX` client:
  * Name: "conection name"
  * Client ID: "unique id string"
  * Host: mqtt:// "your server ip"
  * Port: 1883
  * Username: \<null\>
  * Password: \<null\>
  * SSL/TLS: off
  * Clean Session: false
  * MQTT Version: 3.1.1

## make deb for AO(TBC on SGW7000)
```bash
./make_deb.sh
```
