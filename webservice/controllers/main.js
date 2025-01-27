export default class MainController {

  /**
   * Default entry point
   * @returns Json app info
   */
  async index(ctx) {
    ctx.log.info('index');

    const client = ctx.whois();
    ctx.log.debug(`Request from ${client}`);

    await ctx.render({
      json: {
        message: ctx.app.config.ws.message,
        client: client,
        version: ctx.app.config.ws.version
      }
    });
  }

  /**
   * Organization
   * @returns Json oranization info
   */
  async organization(ctx) {
    ctx.log.info('organization');

    // get data from db
    var json_data = await ctx.models.main.getOrganization();
    await ctx.render({ json: json_data || {} });
  }

  /**
   * Login
   * @param user User data object from client
   * @returns Json object with result and valid token if login is successful
   */
  async login(ctx) {
    ctx.log.info('login');

    // ctx.logObj("method", ctx.req.method);
    // ctx.logObj("path", ctx.req.path);
    // ctx.logObj("baseURL", ctx.req.baseURL);
    // ctx.logObj("userinfo", ctx.req.userinfo);
    // ctx.logObj("requestId", ctx.req.requestId);

    // Retrieve request body as parsed JSON
    const data = await ctx.req.json();
    ctx.logObj('data', data);
    const loginData = {
      email: data['email'],
      password: data['password']
    }

    // Log
    ctx.log.debug(`User ${loginData.email} is trying to login ..`);
    // ctx.log.debug(`email: ${loginData.email}`);
    // ctx.log.debug(`password: ${loginData.password}`);
    // ctx.log.debug(`config secret: ${ctx.config.jwt.secret}`);
    ctx.log.debug(`Config tokenLife: ${ctx.config.jwt.tokenLife}`);

    // Sanity check
    ctx.log.debug("Sanity check");
    if (loginData.email === undefined || loginData.password === undefined) {
      ctx.log.info('Invalid mail or password fields provided');
      await ctx.render({
        json: {
          message: "Invalid mail or password fields provided",
        }, status: 400 // Bad request
      });
      return;
    }

    // do the database authentication here, with user name and password combination.
    // encryptedPassword = await bcrypt.hash(password, 10);
    ctx.log.debug("Database authentication");
    ctx.logObj('getUser', loginData);
    var user = await ctx.models.main.getUser(loginData);
    if (user === undefined) {
      ctx.log.info('User not found');
      await ctx.render({
        json: {
          message: "User not found",
        }, status: 401 // Unauthorized
      });
      return;
    }
    // ctx.logObj('user', user);
    ctx.log.debug(`User name: ${user.us_name}`);

    // Sign in with jwt token
    ctx.log.info('Sign via JWT token');
    // create a new token
    const token = ctx.jwtSign(user, ctx.config.jwt.access);
    const refreshToken = ctx.jwtSign(user, ctx.config.jwt.refresh);

    // Get the decoded payload and header
    var decoded = ctx.jwtDecode(token);

    // Render back json
    ctx.res.setCookie('refreshToken', refreshToken, { httpOnly: true, sameSite: 'strict' });
    await ctx.render({
      json: {
        message: "Logged in",
        algorithm: decoded.header.alg,
        exp: decoded.payload.exp,
        iat: decoded.payload.iat,
        token: token,
        token_type: "Bearer",
        refreshToken: refreshToken
      }, status: 200 // OK
    });
  }

  /**
  * Refresh token
  * @returns Jwt token
  */
  async refreshToken(ctx) {
    ctx.log.info('refreshToken');

    // Retrieve request body as parsed JSON
    const data = await ctx.req.json();
    // ctx.logObj('data', data);

    // get token
    const refreshToken = data['refreshToken'];
    ctx.log.debug(`refreshToken: ${refreshToken}`);

    // validate refresh token
    const res = await ctx.jwtValidate(refreshToken, ctx.config.jwt.refresh);
    if (!res.isValid) {
      ctx.log.info('Invalid refresh token');
      await ctx.render({
        json: {
          message: "Invalid refresh token",
        }, status: 400 // Bad request
      });
      return;
    }

    // get user
    const user = await ctx.jwtDecodeUser(refreshToken);

    // create a new token
    const token = ctx.jwtSign(user, ctx.config.jwt.access);
    // const refreshToken = ctx.jwtSign(user, ctx.config.jwt.refresh);

    // Render back json
    await ctx.render({
      json: {
        token: token
        // refreshToken: refreshToken
      }, status: 200 // OK
    });
  }

  /**
  * Logout
  * @returns Json logout data
  */
  async logout(ctx) {
    ctx.log.info('logout');

    // jwt.sign(authHeader, "", { expiresIn: 1 }, (logout, err) => {
    // Render back json
    await ctx.render({
      json: {
        message: 'Logged out',
      }, status: 200
    });

    // // get token
    // const token = ctx.logObj('token decoded', decoded);

    // // validate token
    // const res = ctx.jwtValidate(token);
    // if (res.isValid) {

    //   // Render back json
    //   await ctx.render({
    //     json: {
    //       message: 'Logged out',
    //     }, status: 200
    //   });

    // } else {
    //   ctx.log.debug("token not valid or expired");
    //   await ctx.render({
    //     json: {
    //       message: 'Token not valid or expired',
    //       error: res.err
    //     }, status: 401 // Unauthorized
    //   });
    // }
  }

  /**
   * Dashboard
   * @returns Json dashboard info
   */
  async dashboard(ctx) {
    ctx.log.info("dashboard");

    // get token
    const token = await ctx.authExtractToken();

    // get user
    const user = await ctx.jwtDecodeUser(token);

    // render back
    await ctx.render({
      json: {
        'message': 'Dashboard info',
        'user.name': user.us_name,
        'user.surname': user.us_surname,
        'requests': {
          'public': {
            'a': '/',
            'b': '/organization',
            'c': '/login',
          },
          'reserved': {
            'a': '/login',
            'b': '/dashboard',
            'c': '/stations',
            'd': '/stations/:station-id',
            'e': '/parameters',
            'f': '/parameters/:parameter-id',
            'g': '/data_station/:station-id/:hours',
            'h': '/series',
            'i': '/data-series/:series-id/:hours',
            'l': '/data-series/:series-id/:et-from/:et-to',
          }
        },
        'data.quality': {
          '-1': 'Valido come sospetto',
          '0': 'Valido',
          '1': 'Valido come dato ricostruito',
        },
        'organization': ctx.app.config.organization
      }, status: 200 // OK

    });
  }
}
