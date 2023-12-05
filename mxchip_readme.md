# Modify for AO-SGW7000

- 2023.11.23
- For MQTT client disconnect notify issue

## Build nanomq

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
```


## Code modifications by MXCHIP@2023.10.20 
1. TCP keepalive disabled by default.
- file: nng/src/core/socket.c
```c
static int
nni_sock_create(nni_sock **sp, const nni_proto *proto)
{
  	on = false; //MXCHIP@20231020: NOTE socket keepalive disabled	
	(void) nni_sock_setopt(
	    s, NNG_OPT_TCP_KEEPALIVE, &on, sizeof(on), NNI_TYPE_BOOL);
}
  ```

2. keepalive timeout bug
- file: nng/src/sp/protocol/mqtt/nmq_mqtt.c
```c
static void
nano_pipe_timer_cb(void *arg)
{
    // ...
    qos_backoff = p->ka_refresh * (qos_duration) *1000 -
		// p->keepalive * qos_backoff * 1000;
	    p->keepalive * qos_backoff; //MXCHIP@20231020: qos_backoff unit ms.
	if (qos_backoff > 0) {
		nni_println(
		    "Warning: close pipe & kick client due to KeepAlive "
		    "timeout!");
		p->reason_code = NMQ_KEEP_ALIVE_TIMEOUT;
		nni_sleep_aio(qos_duration * 1000, &p->aio_timer);
		nni_mtx_unlock(&p->lk);
		nni_aio_finish_error(&p->aio_recv, NNG_ECONNREFUSED);
		return;
    }
    // ...
}
```

3. feature(close silently and cache the pipe if clean_start == 0), enable disconnect notify for AOedge project: 
- file: file: nng/src/sp/protocol/mqtt/nmq_mqtt.c
```c
nano_pipe_close(void *arg)
{
	nano_pipe *p = arg;
	nano_sock *s = p->broker;
	nano_ctx  *ctx;
	nni_aio   *aio = NULL;
	nni_msg   *msg;
	nni_pipe  *npipe        = p->pipe;
	char      *clientid     = NULL;
	uint32_t   clientid_key = 0;

	log_trace(" ############## nano_pipe_close ############## ");
	if (npipe->cache == true) {
		// not first time we trying to close stored session pipe
		nni_atomic_swap_bool(&npipe->p_closed, false);
		return;
	}
	nni_mtx_lock(&s->lk);
	// we freed the conn_param when restoring pipe
	// so check status of conn_param. just let it close silently
	if (p->conn_param->clean_start == 0) {
		// cache this pipe
		clientid = (char *) conn_param_get_clientid(p->conn_param);
	}
	if (clientid) {
		clientid_key = DJBHashn(clientid, strlen(clientid));
		nni_id_set(&s->cached_sessions, clientid_key, p);
		nni_mtx_lock(&p->lk);
		// set event to false avoid of sending the disconnecting msg
		// p->event                   = false;
		p->event                   = true;  //MXCHIP@20231020: need notify for AOedge project.
		npipe->cache               = true;
		p->conn_param->clean_start = 1;
		nni_atomic_swap_bool(&npipe->p_closed, false);
		if (nni_list_active(&s->recvpipes, p)) {
			nni_list_remove(&s->recvpipes, p);
		}
		nano_nni_lmq_flush(&p->rlmq, false);
		// nni_mtx_unlock(&s->lk); //MXCHIP@20231020: need notify for AOedge project.
		nni_mtx_unlock(&p->lk);
		// return; //MXCHIP@20231020: need notify for AOedge project, keep pipe.
	}
	// close_pipe(p);
	else //MXCHIP@20231020: need notify for AOedge project.
	{
		close_pipe(p);
	}
	// ...
```


## make deb for AO
```bash
./make_deb.sh
```
