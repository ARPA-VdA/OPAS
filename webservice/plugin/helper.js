import jwt from 'jsonwebtoken'
import util from 'util'

// https://mojojs.org/docs/Cookbook.md#adding-plugins-to-your-application

export default function helperPlugin(app) {

  /**
   * Dump object to console
   */
  app.addHelper('logObj', (ctx, info, obj) => {
    ctx.log.debug('Helper logObj');

    ctx.log.debug(info + ": " + util.inspect(obj, {
      showHidden: true, depth: 4,
      colorize: true, compact: false
    }));
  });

  /**
   * Helper to identify visitors
   * @returns user agent and ip
   */
  app.addHelper('whois', ctx => {
    ctx.log.info('Helper whois');

    const agent = ctx.req.get('User-Agent') ?? 'Anonymous';
    const ip = ctx.req.ip;
    return `${agent} (${ip})`;
  });

  /**
   * Extract token from bearer authentication
   * @param ctx request
   * @returns token string
   */
  app.addHelper('authExtractToken', ctx => {
    ctx.log.info('Helper authExtractToken');

    // get bearer <token>
    const authHeader = ctx.req.get('Authorization');
    ctx.log.trace(`authHeader: ${authHeader}`);
    // sanity check
    if (!authHeader)
      return null;
    const token = authHeader.split(" ")[1];
    ctx.log.trace(`token: ${token}`);

    // return token
    return token;
  });

  /**
   * Sign in jwt token
   * @param data Application data
   * @param user user object from db
   * @returns jwt token
   */
  app.addHelper('jwtSign', (ctx, user, jwtConf) => {
    ctx.log.info('Helper jwtSign');

    // https://github.com/auth0/node-jsonwebtoken

    // create token with secret salt
    // var token = jwt.sign({ foo: 'bar' }, privateKey, { algorithm: 'RS256' });
    const token = jwt.sign(
      { user: user },
      jwtConf.secret,
      { expiresIn: jwtConf.tokenLife }
    );
    ctx.log.debug(`Token: ${token}`);
    return token;
  });

  /**
   * Verify jwt token and validate errors
   * @param token valid jwt token
   * @returns custom res object
   */
  app.addHelper('jwtValidate', (ctx, token, jwtConf) => {
    ctx.log.info('Helper jwtValidate');
    // ctx.logObj('token', token);
    // ctx.logObj('jwtConf', jwtConf);

    // default reply
    let res = { isValid: null, err: null };

    // check token against secret salt
    jwt.verify(token, jwtConf.secret, function (err, decoded) {
      if (err) {
        ctx.log.error(`jwt verify err: ${err}`);

        if (err.name == 'JsonWebTokenError') {
          /*
            err = {
              name: 'JsonWebTokenError',
              message: 'jwt malformed'
            }
          */
          ctx.log.debug('JsonWebTokenError');

        } else if (err.name == 'TokenExpiredError') {
          /*
            err = {
              name: 'TokenExpiredError',
              message: 'jwt expired',
              expiredAt: 1408621000
            }
          */
          ctx.log.debug('TokenExpiredError');

        } else if (err.name == 'NotBeforeError') {
          /*
            err = {
              name: 'NotBeforeError',
              message: 'jwt not active',
              date: 2018-10-04T16:10:44.000Z
            }
          */
          ctx.log.debug('NotBeforeError');

        } else {
          ctx.log.debug('Unknown Error');
        }

        // res object
        res = {
          isValid: false,
          err: err
        }

      } else {
        // token ok
        ctx.log.debug('Token is valid');
        // ctx.log.debug(decoded);

        // res object
        res = {
          isValid: true,
          err: null
        }
      }
    });

    // return object
    return res;
  });

  /**
   * Decode jwt token for info
   * @param token a valid jwt token
   * @returns jwt decoded items
   */
  app.addHelper('jwtDecode', (ctx, token) => {
    ctx.log.info('Helper jwtDecode');

    var decoded = jwt.decode(token, { complete: true });
    ctx.logObj('token decoded', decoded);

    // decoded all items (header, payload, signature)
    return decoded;
  });

  /**
   * Parse jwt token from header against secret salt
   * @returns jwt decoded payload
   */
  app.addHelper('jwtDecodePayload', (ctx, token, jwtConf) => {
    ctx.log.info('Helper jwtDecodePayload');

    // invalid token - synchronous
    var decoded = undefined;
    try {
      // decode with against secret salt
      decoded = jwt.verify(token, jwtConf.secret);
    } catch {
      // err
    }
    ctx.logObj('token decoded', decoded);

    // decoded payload only
    return decoded;
  });

  /**
 * Decode jwt token for info
 * @param token a valid jwt token
 * @returns jwt decoded user
 */
  app.addHelper('jwtDecodeUser', (ctx, token) => {
    ctx.log.info('Helper jwtDecodeUser');

    var decoded = jwt.decode(token, { complete: true });
    ctx.logObj('token decoded', decoded);

    // decoded user
    return decoded.payload.user;
  });

}
