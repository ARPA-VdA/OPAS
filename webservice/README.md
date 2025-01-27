# PROJECT opas-api

### Public routes

```code
    ○ Index                                   ✓
    ○ User login                              ✓
    ○ User logout                             ✓
    ○ Get organization info                   ✓
```

### Reserved token based routes

```code
    ○ Refresh token                           ✓
    ○ Dashboard                               ✓
    ○ Get stations                            ✓
    ○ Get stations/id                         ✓
    ○ Get parameters                          ✓
    ○ Get parameters/id                       ✓
    ○ Get stations_parameters/id              ✓
    ○ Get sites                               ✓
    ○ Get campaigns per station               ✓
    ○ Get campaigns per station and date      ✓
    ○ Get series                              ✓
    ○ Get latest data per series              ✓
    ○ Get latest data per station
    ○ Get data frame per series               ✓
    ○ Get data frame per station
```

### Use HTTP methods explicitly

```code
    ○ GET - for Read
    ○ POST - for Create
    ○ PUT - for Update
    ○ DELETE - for Delete
```

### HTTP codes

```code
    ○ 200 OK
    ○ 400 Bad Request
    ○ 401 Unauthorized
    ○ 403 Forbidden
    ○ 404 Not Found
    ○ 408 Request Timeout
    ○ 500 Internal Server Error
    ○ 502 Bad Gateway
```

# GIT

token: git: When Git prompts you for your password, enter your personal access token

https://github.com/settings/tokens

### git config

```Git Config
    git config --global user.name ""
    git config --global user.email ""

    git status
    git add .
    git commit -m ""
    git push
```

# DOCS

https://mojojs.org/docs/Cookbook.md#toc

https://mojojs.org/docs/Rendering.md

https://github.com/mojolicious/pg.js

https://github.com/mojolicious/pg.js/blob/main/examples/blog/models/posts.js

https://codeforgeek.com/refresh-token-jwt-nodejs-authentication/
https://medium.com/@techsuneel99/jwt-authentication-in-nodejs-refresh-jwt-with-cookie-based-token-37348ff685bf
https://medium.com/@kizito917/jwt-refresh-token-implementation-with-node-js-postgres-and-sequelize-106ef6b3de68

https://www.bezkoder.com/node-js-jwt-authentication-postgresql/

https://restfulapi.net/resource-naming/

### jwt

https://jwt.io/

### node pg

https://node-postgres.com/

# NODEJS

### Install nodejs

```bash
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    command -v nvm
    nvm install --lts
    nvm ls
    node --version
    npm --version
```

### Upgrade nodejs

```bash
    nvm ls         -> list local
    nvm ls-remote  -> list online
    nvm install --lts

    # via check-updates
    npm install --global npm-check-updates
    npm-check-updates --upgrade
    -> ncu
```

### Nodemon

```bash
    npm install -g nodemon
```

#### Install/Upgrade packages

```bash
    npm install

    # or single packaes
    npm install @mojojs/core
    npm install @mojojs/pg
    #npm install jsonwebtoken
    npm install --save-dev @types/jsonwebtoken
    #npm install bcrypt
    npm install --save-dev @types/bcrypt
    npm install moment
    npm install object-sizeof
    npm install byte-size
    npm install node-gzip
    npm install nodemon
    # mode node
    npm init @eslint/config

    -- version (npm list -g --depth=0)
    npm list
        git-bobo-api@ /mnt/c/Dev/git-bobo-api
        ├── @eslint/eslintrc@3.0.2
        ├── @eslint/js@9.1.1
        ├── @mojojs/core@1.26.4
        ├── @mojojs/pg@1.2.0
        ├── @types/bcrypt@5.0.2
        ├── @types/jsonwebtoken@9.0.6
        ├── bcrypt@5.1.1
        ├── dotenv@16.4.5
        ├── eslint-config-standard@17.1.0
        ├── eslint-plugin-import@2.29.1
        ├── eslint-plugin-n@16.6.2
        ├── eslint-plugin-promise@6.1.1
        ├── eslint@8.57.0
        ├── globals@15.0.0
        ├── jsonwebtoken@9.0.2
        ├── moment@2.30.1
        ├── nodemon@3.1.0
        ├── pg@8.11.5
        └── tap@18.7.2
```

#### create path and app

```bash
    mkdir bobo-api && cd bobo-api
    npm create @mojojs/full-app
    #npm create @mojojs/lite-app
    npm install
```

### logging

The default operating mode is development, which sets the log level of app.log and ctx.log to the lowest level (trace). All other modes raise the level to info.

### coding

coding style: https://github.com/felixge/node-style-guide

# RUNNING

```shell
    npx nodemon index.js server
    MOJO_PG_DEBUG=1 npx nodemon index.js server
    NODE_ENV=production npx nodemon index.js server
    # type "rs" in the console to reload

    # from script
    or ./start.sh
```

### Set ENV variables

```shell
    # endpoint
    export ENDPOINT=http://127.0.0.1:3000
    export ENDPOINT=https://xxxx/api/v1
    # user
    export USER='user_name'
    export PASS='password'

    # from script - set environment variables
    source ./environment.sh
```

### Running test

```shell
    # "Info" section tests
    node test/ws-info.js
    # "Authorization" section tests
    node test/ws-auth.js
    # "Metadata" section tests
    node test/ws-metadata.js
    # "Data" section tests
    node test/ws-data.js
```

### info

```bash
    # test ws
    curl $ENDPOINT/ | jq

    # more info
    curl -i $ENDPOINT/
        HTTP/1.1 200 OK
        Access-Control-Allow-Origin: *
        Content-Type: application/json; charset=utf-8
        Content-Length: 73
        Date: Tue, 06 Jun 2023 09:21:27 GMT
        Connection: keep-alive
        Keep-Alive: timeout=5
        {"result":"ok","message":"mojo.js restful web service","version":"1.0.0"}
```

# Routes

### public routes

```bash
    curl $ENDPOINT/organization | jq
```

### private routes - login and token (access_token)

```bash
    # login
    curl -d '{"email":"'$USER'", "password":"'$PASS'"}' \
        -H "Content-Type: application/json" -X POST $ENDPOINT/login | jq

    # login with saved result to extract tokens
    API_RES=$(
        curl -d '{"email":"'$USER'", "password":"'$PASS'"}' \
        -H "Content-Type: application/json" \
        -X POST $ENDPOINT/login
    )
    TOKEN=$(jq -r '.token' <<<"$API_RES")
    REFRESH_TOKEN=$(jq -r '.refreshToken' <<<"$API_RES")

    # refresh token
    curl -d '{"refreshToken":"'$REFRESH_TOKEN'"}' \
        -H "Content-Type: application/json" \
        -X POST $ENDPOINT/refresh-token | jq -r  '.token'
```

### private routes

```bash
    # logout
    curl $ENDPOINT/logout --Header "Authorization: Bearer $TOKEN" | jq

    #
    # metadata
    #

    # dashboard
    #   * /dashboard
    curl $ENDPOINT/dashboard --Header "Authorization: Bearer $TOKEN" | jq

    # stations list
    #   * /stations
    curl $ENDPOINT/stations --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/stations --Header "Authorization: Bearer $TOKEN" | jq -r '.stations | length'
    curl $ENDPOINT/stations --Header "Authorization: Bearer $TOKEN" | jq -r '.stations[].id'

    # station list per region
    #   * /stations/{region_istat_code}
    curl $ENDPOINT/stations/02 --Header "Authorization: Bearer $TOKEN" | jq

    # station detail & owned parameters
    #   * /stations/{station_id}
    curl $ENDPOINT/stations/1000 --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/stations/1159 --Header "Authorization: Bearer $TOKEN" | jq # few parameters (1403)

    # parameters list
    #   * /parameters
    curl $ENDPOINT/parameters --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/parameters --Header "Authorization: Bearer $TOKEN" | jq -r '.parameters | length'

    # parameter detail
    #  * /parameters/{parameter_id}
    curl $ENDPOINT/parameters/1 --Header "Authorization: Bearer $TOKEN" | jq

    # stations parameter list
    #  * /stations-parameters/{station_id}/{parameter_id}
    curl $ENDPOINT/stations-parameters/1000/1 --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/stations-parameters/1159/1 --Header "Authorization: Bearer $TOKEN" | jq

    # sites list
    #  * /sites
    curl $ENDPOINT/sites --Header "Authorization: Bearer $TOKEN" | jq

    # campaigns per station id
    #  * /campaigns/{station_id}
    curl $ENDPOINT/campaigns/1007 --Header "Authorization: Bearer $TOKEN" | jq

    # campaigns per station id and date
    #  * /campaigns/{station_id}/{date_time}
    curl $ENDPOINT/campaigns/1007/`date -d '1 year ago' "+%s"` --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/campaigns/1007/2023-01-01T00:00:00 --Header "Authorization: Bearer $TOKEN" | jq

    #
    # data
    #

    # series list
    #  * /series
    curl $ENDPOINT/series --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series --Header "Authorization: Bearer $TOKEN" | jq -r '.series | length' # series

    # series list per region
    #  * /series/{region_istat_code}
    curl $ENDPOINT/series/02 --Header "Authorization: Bearer $TOKEN" | jq

    # series list per station
    #  * /series/{station_id}
    curl $ENDPOINT/series/1000 --Header "Authorization: Bearer $TOKEN" | jq

    # data per series latest hours (2011 temp plouves)
    #  * /series-data/{series_id}/{hours}
    curl $ENDPOINT/series-data/2011/24 --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series-data/1996/24 --Header "Authorization: Bearer $TOKEN" | jq # (mont fleury temp)

    # data per series by dates
    #  * /series-data/{series_id}/{start_date_time}/{end_date_time}
    curl $ENDPOINT/series-data/2011/1711584000/1711670400 --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series-data/2011/2024-04-01T00:00:00/2024-04-01T23:59:59 --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series-data/2011/`date -d '3 hour ago' "+%s"`/`date '+%s'` --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series-data/2011/`date -d '1 year ago' "+%s"`/`date '+%s'` --Header "Authorization: Bearer $TOKEN" > 1year.txt

    # synchro data per series by dates
    #  * /series-data-synchro/{series_id}/{last_ie_date_time}
    curl $ENDPOINT/series-data-synchro/2011/1711584000 --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series-data-synchro/2011/2024-04-01T00:00:00 --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series-data-synchro/2011/`date -d '3 hour ago' "+%s"` --Header "Authorization: Bearer $TOKEN" | jq
    curl $ENDPOINT/series-data-synchro/2011/`date -d '1 year ago' "+%s"` --Header "Authorization: Bearer $TOKEN" > edited1yearago.txt

    # per station
    #  * /series-data-synchro-all/{station_id}/{last_ie_date_time}
    curl $ENDPOINT/series-data-synchro-all/1000/`date -d '3 hour ago' "+%s"` --Header "Authorization: Bearer $TOKEN" | jq

    # per region
    #  * /series-data-synchro-all/{region_istat_code}/{last_ie_date_time}
    curl $ENDPOINT/series-data-synchro-all/02/`date -d '3 hour ago' "+%s"` --Header "Authorization: Bearer $TOKEN" | jq
```

# DEPLOY

https://mojojs.org/docs/Cookbook.md#toc

### running in console

```bash
    node index.js server -l http://0.0.0.0:8001
    NODE_ENV=production node index.js server -l http://0.0.0.0:8001
    NODE_ENV=production node  -c -w 4 index.js server -l http://0.0.0.0:8001
```

### via systemd

```bash
    mkdir -p ~/.config/systemd/user
    nano ~/.config/systemd/user/opasapi.service

    systemctl --user daemon-reload
    systemctl --user enable opasapi.service
    systemctl --user is-enabled opasapi.service

    systemctl --user start opasapi.service
    systemctl --user stop opasapi.service
    systemctl --user restart opasapi.service
    systemctl --user status opasapi.service
        Loaded: loaded (/home/opas/.config/systemd/user/opasapi.service; enabled; vendor preset: enabled)
            Active: active (running) since Fri 2024-03-29 16:14:09 UTC; 1s ago
        Main PID: 3362514 (node)
            Tasks: 11 (limit: 18987)
            Memory: 31.1M
                CPU: 506ms
            CGroup: /user.slice/user-1000.slice/user@1000.service/app.slice/opasapi.service
                    └─3362514 /home/opas/.nvm/versions/node/v20.12.0/bin/node /home/opas/www/api/index.js server -l "http://*:3001"

    tail -f /www/opas_api_node/log/opas_api.log
```

##### cat ~/.config/systemd/user/opasapi.service

```Ini
[Unit]
Description=Opas Api application
After=network.target

[Service]
Type=simple
Environment=NODE_ENV=production
ExecStart=/home/USER/.nvm/versions/node/v18.17.1/bin/node /www/opas_api_node/index.js server -l http://*:8001

[Install]
WantedBy=multi-user.target
```

#### endpoint

https://opas-api.isprambiente.it/
https://opas.isprambiente.it/api/v1/

# DOCUMENTATION

#### api

https://swagger.io/specification/
https://medium.com/@isuriamasarani87/rest-url-naming-conventions-ef8cb67df5a3

#### Puntatore aggiornamento dati in UTC

L'ora di riferimento da utilizzare è quella SOLARE GMT+1, la stessa impostata in tutte le stazioni, senza passaggio dall'ora legale all'ora solare, per cui in questo istante 08:29 corrisponde a 07:29 e l'ultimo dato disponibile nel db sarà targato "06:00:00" che è la media di tutti i dati tra le 06:00:00 e le 06:59:59.

L'ora del puntatore utilizzato dal web service {last_ie_date_time} è impostato in orario UTC.
