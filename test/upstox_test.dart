import 'package:flutter_test/flutter_test.dart';
import 'package:odin_trader/config/upstox_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odin_trader/data/scrip_catalog.dart';
import 'package:odin_trader/data/scrip_master_parser.dart';
import 'package:odin_trader/data/upstox_instruments.dart';
import 'package:odin_trader/models/candle.dart';
import 'package:odin_trader/models/upstox_account.dart';
import 'package:odin_trader/services/upstox_auth.dart';
import 'package:odin_trader/services/upstox_market_client.dart';
import 'package:odin_trader/state/upstox_account_controller.dart';
import 'package:odin_trader/state/upstox_controller.dart';

void main() {
  test('round robin cycles ready access tokens', () async {
    final upstox = UpstoxController(
      tokenExchanger: ({
        required code,
        required apiKey,
        required apiSecret,
        required redirectUrl,
      }) async {
        return {'access_token': 'token-$apiKey', 'user_id': 'U1'};
      },
    );

    expect(upstox.slots, hasLength(6));
    expect(upstox.redirectUrl, upstoxRedirectUrl);
    expect(upstox.slots.first.apiKey, upstoxDefaultApiKeys.first);
    expect(upstox.slots.last.apiSecret, upstoxDefaultApiSecrets.last);
    expect(upstox.nextAccessToken(), isNull);

    await upstox.exchangeCode(0, 'code-0');
    await upstox.exchangeCode(1, 'code-1');
    await upstox.exchangeCode(2, 'code-2');

    expect(upstox.primaryAccessToken(), 'token-${upstoxDefaultApiKeys[0]}');
    expect(upstox.nextAccessToken(), 'token-${upstoxDefaultApiKeys[0]}');
    expect(upstox.nextAccessToken(), 'token-${upstoxDefaultApiKeys[1]}');
    expect(upstox.nextAccessToken(), 'token-${upstoxDefaultApiKeys[2]}');
    expect(upstox.nextAccessToken(), 'token-${upstoxDefaultApiKeys[0]}');
  });

  test('persists edited keys and secrets across restart', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final first = UpstoxController(persistEnabled: true);
    await first.updateCredentials([
      (apiKey: 'key-a', apiSecret: 'secret-a'),
      (apiKey: 'key-b', apiSecret: 'secret-b'),
      for (var i = 2; i < UpstoxController.slotCount; i++)
        (apiKey: 'key-$i', apiSecret: 'secret-$i'),
    ]);
    await first.setRedirectUrl('https://www.flyspring.in/api/setToken');

    final second = UpstoxController(persistEnabled: true);
    await second.load();
    expect(second.redirectUrl, 'https://www.flyspring.in/api/setToken');
    expect(second.slots[0].apiKey, 'key-a');
    expect(second.slots[0].apiSecret, 'secret-a');
    expect(second.slots[1].apiKey, 'key-b');
    expect(second.slots[1].apiSecret, 'secret-b');
    expect(second.slots[5].apiKey, 'key-5');
  });

  test('detects Flyspring Upstox redirect URL', () {
    expect(
      isUpstoxRedirect(
        Uri.parse('https://www.flyspring.in/api/setToken?code=abc'),
        upstoxRedirectUrl,
      ),
      isTrue,
    );
    expect(
      isUpstoxRedirect(
        Uri.parse('https://api.upstox.com/v2/login/authorization/dialog'),
        upstoxRedirectUrl,
      ),
      isFalse,
    );
  });

  test('groups Upstox order statuses', () {
    expect(groupUpstoxOrder('open'), UpstoxOrderGroup.pending);
    expect(groupUpstoxOrder('trigger pending'), UpstoxOrderGroup.pending);
    expect(groupUpstoxOrder('complete'), UpstoxOrderGroup.executed);
    expect(groupUpstoxOrder('cancelled'), UpstoxOrderGroup.cancelled);
    expect(
      groupUpstoxOrder('cancelled after market order'),
      UpstoxOrderGroup.cancelled,
    );
    expect(groupUpstoxOrder('rejected'), UpstoxOrderGroup.rejected);
  });

  test('position summary maps buy and sell qty and price', () {
    final position = UpstoxPosition.fromJson({
      'tradingsymbol': 'RELIANCE',
      'quantity': 20,
      'average_price': 2874.1,
      'last_price': 2912.4,
      'pnl': 766,
      'unrealised': 766,
      'realised': 0,
      'day_buy_quantity': 20,
      'day_buy_price': 2874.1,
      'day_sell_quantity': 5,
      'day_sell_price': 2910,
      'instrument_token': 'NSE_EQ|INE002A01018',
      'product': 'D',
    });
    expect(position.buyQuantity, 20);
    expect(position.buyPrice, 2874.1);
    expect(position.sellQuantity, 5);
    expect(position.sellPrice, 2910);
    expect(position.productLabel, 'Delivery');
  });

  test('hides invalid token errors from screen copy', () {
    expect(isUpstoxAuthError('Invalid token used to access API'), isTrue);
    expect(visibleUpstoxError('Invalid token used to access API'), isNull);
    expect(upstoxLinkLabel(UpstoxLinkState.offline), 'Upstox not connected');
    expect(upstoxLinkLabel(UpstoxLinkState.invalid), 'Upstox token invalid');
  });

  test('rewrites Upstox fund service hours errors', () {
    const raw =
        'The fund service is accessiable from 5.30 AM to 12 AM IST daily, please try again during these service hours.';
    expect(isUpstoxHoursError(raw), isTrue);
    expect(friendlyUpstoxError(raw), upstoxFundsHoursMessage);
  });

  test('parses Upstox option chain strikes and quotes', () {
    expect(isoExpiryDate('29-09-2026'), '2026-09-29');
    final chain = parseUpstoxOptionChain({
      'data': [
        {
          'strike_price': 24800,
          'underlying_spot_price': 24780.3,
          'call_options': {
            'instrument_key': 'NSE_FO|52567',
            'market_data': {
              'ltp': 120.5,
              'close_price': 110,
              'oi': 150000,
              'prev_oi': 140000,
              'volume': 8200,
            },
            'option_greeks': {'delta': 0.44, 'iv': 13.2},
          },
          'put_options': {
            'instrument_key': 'NSE_FO|52568',
            'market_data': {
              'ltp': 98.2,
              'close_price': 105,
              'oi': 180000,
              'prev_oi': 170000,
            },
          },
        },
        {
          'strike_price': 24700,
          'call_options': {
            'instrument_key': 'NSE_FO:52561',
            'market_data': {'ltp': 180.1, 'close_price': 170},
          },
          'put_options': {
            'instrument_key': 'NSE_FO|52562',
            'market_data': {'ltp': 70.4, 'close_price': 80},
          },
        },
      ],
    });
    expect(chain.spot, 24780.3);
    expect(chain.rows.map((row) => row.strike), [24700.0, 24800.0]);
    expect(chain.tokens, [
      'NSE_FO|52561',
      'NSE_FO|52562',
      'NSE_FO|52567',
      'NSE_FO|52568',
    ]);
    expect(
      chain.quotes
          .firstWhere((row) => row.instrumentKey == 'NSE_FO|52561')
          .quote
          .ltp,
      180.1,
    );
    expect(
      chain.quotes.firstWhere((row) => row.instrumentKey == 'NSE_FO|52567').quote.change,
      10.5,
    );
    expect(
      chain.quotes
          .firstWhere((row) => row.instrumentKey == 'NSE_FO|52567')
          .quote
          .openInterest,
      150000,
    );
  });

  test('parses Upstox required and final margin', () {
    final quote = UpstoxMarginQuote.fromJson({
      'required_margin': 25000,
      'final_margin': 18000,
    });
    expect(quote.requiredMargin, 25000);
    expect(quote.finalMargin, 18000);
    expect(quote.benefit, 7000);
  });

  test('maps scrips to Upstox instrument keys', () {
    expect(
      upstoxInstrumentKey(
        token: '1_2885',
        symbol: 'RELIANCE',
        isin: 'INE002A01018',
      ),
      'NSE_EQ|INE002A01018',
    );
    expect(
      upstoxInstrumentKey(
        token: '2_52567',
        symbol: 'NIFTY',
        kind: ScripKind.option,
      ),
      'NSE_FO|52567',
    );
    expect(
      upstoxInstrumentKey(
        token: '1_26000',
        symbol: 'NIFTY',
        kind: ScripKind.idx,
      ),
      'NSE_INDEX|Nifty 50',
    );
    expect(upstoxFoKeyFromToken('2_90005'), 'NSE_FO|90005');
    expect(
      upstoxInstrumentKey(
        token: 'NSE_FO|52567',
        symbol: 'NIFTY',
        kind: ScripKind.option,
      ),
      'NSE_FO|52567',
    );
    expect(upstoxFoKeyFromToken('NSE_FO|52567'), 'NSE_FO|52567');
  });

  test('parses Upstox full market quotes into app quotes', () {
    final quotes = parseUpstoxQuoteMap({
      'data': {
        'NSE_EQ:INE002A01018': {
          'instrument_token': 'NSE_EQ|INE002A01018',
          'last_price': 2912.4,
          'net_change': 34.15,
          'oi': 0,
          'volume': 1823400,
          'lower_circuit_limit': 2610.2,
          'upper_circuit_limit': 3190.5,
          'week_52_high': 3200,
          'week_52_low': 2200,
          'ohlc': {
            'open': 2880.0,
            'high': 2924.5,
            'low': 2871.1,
            'close': 2878.25,
          },
          'depth': {
            'buy': [
              {'price': 2912.0, 'quantity': 120},
              {'price': 2911.5, 'quantity': 80},
            ],
            'sell': [
              {'price': 2912.6, 'quantity': 90},
            ],
          },
        },
      },
    });
    expect(quotes, hasLength(1));
    expect(quotes.single.instrumentKey, 'NSE_EQ|INE002A01018');
    expect(quotes.single.quote.ltp, 2912.4);
    expect(quotes.single.quote.change, 34.15);
    expect(quotes.single.quote.open, 2880.0);
    expect(quotes.single.quote.week52High, 3200);
    expect(quotes.single.quote.buyDepth.first.qty, 120);
    expect(quotes.single.quote.sellDepth.single.price, 2912.6);
    final greeks = parseUpstoxQuoteMap({
      'data': {
        'NSE_FO:1': {
          'instrument_token': 'NSE_FO|1',
          'last_price': 120.5,
          'iv': 13.2,
          'greeks': {
            'delta': 0.44,
            'gamma': 0.01,
            'theta': -3.8,
            'vega': 7.1,
          },
        },
      },
    });
    expect(greeks.single.quote.delta, 0.44);
    expect(greeks.single.quote.iv, 13.2);
    expect(greeks.single.quote.theta, -3.8);
  });

  test('fetches Upstox market quotes through the market client', () async {
    Future<Map<String, dynamic>> request({
      required List<String> instrumentKeys,
      required String accessToken,
    }) async {
      expect(accessToken, 'token');
      expect(instrumentKeys, ['NSE_EQ|INE002A01018']);
      return {
        'data': {
          'NSE_EQ:INE002A01018': {
            'instrument_token': 'NSE_EQ|INE002A01018',
            'last_price': 2912.4,
            'net_change': 12.2,
            'ohlc': {'open': 2900, 'high': 2920, 'low': 2890, 'close': 2900.2},
          },
        },
      };
    }

    final client = UpstoxMarketClient(requester: request);
    final quotes = await client.fetchQuotes(
      accessToken: 'token',
      instrumentKeys: ['NSE_EQ|INE002A01018', 'NSE_EQ|INE002A01018'],
    );
    expect(quotes.single.quote.ltp, 2912.4);
    expect(quotes.single.quote.change, 12.2);
  });

  test('loads profile, funds and grouped orders from Upstox', () async {
    final auth = UpstoxController(
      tokenExchanger: ({
        required code,
        required apiKey,
        required apiSecret,
        required redirectUrl,
      }) async {
        return {'access_token': 'token', 'user_id': 'FS1042'};
      },
    );
    await auth.exchangeCode(0, 'code');
    final placed = <Map<String, dynamic>>[];
    final modified = <Map<String, dynamic>>[];
    String? cancelled;
    Future<dynamic> request({
      required String method,
      required String path,
      Map<String, dynamic>? body,
      required bool roundRobin,
      String? baseUrl,
    }) async {
      if (path == '/user/profile') {
        return {
          'user_name': 'Mukul',
          'user_id': 'FS1042',
          'email': 'mukul@flyspring.in',
          'exchanges': ['NSE', 'NFO'],
        };
      }
      if (path == '/user/get-funds-and-margin') {
        return {
          'equity': {
            'available_margin': 48200,
            'used_margin': 12450,
            'adhoc_margin': 8000,
            'notional_cash': 0,
          },
        };
      }
      if (path == '/order/retrieve-all') {
        return [
          {
            'trading_symbol': 'INFY',
            'transaction_type': 'SELL',
            'quantity': 25,
            'price': 1882.5,
            'status': 'open',
            'order_id': '1',
          },
          {
            'trading_symbol': 'RELIANCE',
            'transaction_type': 'BUY',
            'quantity': 10,
            'price': 2904,
            'status': 'complete',
            'order_id': '2',
          },
          {
            'trading_symbol': 'TCS',
            'transaction_type': 'BUY',
            'quantity': 5,
            'price': 4195,
            'status': 'cancelled',
            'order_id': '3',
          },
          {
            'trading_symbol': 'SBIN',
            'transaction_type': 'BUY',
            'quantity': 40,
            'price': 808,
            'status': 'rejected',
            'order_id': '4',
          },
        ];
      }
      if (path == '/portfolio/short-term-positions') {
        return [
          {
            'tradingsymbol': 'RELIANCE',
            'quantity': 20,
            'average_price': 2874.1,
            'last_price': 2912.4,
            'pnl': 766,
            'unrealised': 766,
            'realised': 0,
          },
        ];
      }
      if (path == '/order/place') {
        placed.add(body ?? const {});
        return {'order_id': 'OID99'};
      }
      if (path == '/order/modify') {
        modified.add(body ?? const {});
        return {'order_id': 'OID99'};
      }
      if (path.startsWith('/order/cancel')) {
        cancelled = path;
        return {'order_id': '1'};
      }
      return <String, dynamic>{};
    }

    final account = UpstoxAccountController(auth: auth, requester: request);

    await account.refresh();
    expect(account.profile?.userName, 'Mukul');
    expect(account.profile?.userId, 'FS1042');
    expect(account.funds?.availableMargin, 48200);
    expect(account.funds?.usedMargin, 12450);
    expect(account.funds?.collateral, 8000);
    expect(account.countIn(UpstoxOrderGroup.pending), 1);
    expect(account.countIn(UpstoxOrderGroup.executed), 1);
    expect(account.countIn(UpstoxOrderGroup.cancelled), 1);
    expect(account.countIn(UpstoxOrderGroup.rejected), 1);
    expect(account.positions.single.symbol, 'RELIANCE');
    expect(account.dayPnl, 766);

    final orderId = await account.placeOrder(
      instrumentToken: 'NSE_EQ|INE002A01018',
      side: 'BUY',
      quantity: 1,
      product: 'I',
      orderType: 'MARKET',
    );
    expect(orderId, 'OID99');
    expect(placed.single['instrument_token'], 'NSE_EQ|INE002A01018');
    expect(placed.single['transaction_type'], 'BUY');
    expect(placed.single['order_type'], 'MARKET');

    final pending = account.ordersIn(UpstoxOrderGroup.pending).single;
    expect(pending.canModify, isTrue);
    expect(pending.canCancel, isTrue);
    final modifiedId = await account.modifyOrder(
      orderId: pending.orderId,
      quantity: 30,
      orderType: 'LIMIT',
      price: 1875.5,
    );
    expect(modifiedId, 'OID99');
    expect(modified.single['order_id'], '1');
    expect(modified.single['quantity'], 30);
    expect(modified.single['order_type'], 'LIMIT');
    expect(modified.single['price'], 1875.5);

    await account.cancelOrder(pending.orderId);
    expect(cancelled, '/order/cancel?order_id=1');
  });

  test('fund hours error does not block profile orders or positions', () async {
    final auth = UpstoxController(
      tokenExchanger: ({
        required code,
        required apiKey,
        required apiSecret,
        required redirectUrl,
      }) async {
        return {'access_token': 'token', 'user_id': 'FS1042'};
      },
    );
    await auth.exchangeCode(0, 'code');
    Future<dynamic> request({
      required String method,
      required String path,
      Map<String, dynamic>? body,
      required bool roundRobin,
      String? baseUrl,
    }) async {
      if (path == '/user/get-funds-and-margin') {
        throw Exception(
          'The fund service is accessiable from 5.30 AM to 12 AM IST daily, please try again during these service hours.',
        );
      }
      if (path == '/user/profile') {
        return {'user_name': 'Mukul', 'user_id': 'FS1042'};
      }
      if (path == '/order/retrieve-all') {
        return [
          {
            'trading_symbol': 'INFY',
            'transaction_type': 'SELL',
            'quantity': 1,
            'price': 1,
            'status': 'open',
            'order_id': '1',
          },
        ];
      }
      if (path == '/portfolio/short-term-positions') {
        return [
          {
            'tradingsymbol': 'RELIANCE',
            'quantity': 1,
            'average_price': 10,
            'last_price': 12,
            'pnl': 2,
            'unrealised': 2,
            'realised': 0,
          },
        ];
      }
      return <String, dynamic>{};
    }

    final account = UpstoxAccountController(auth: auth, requester: request);

    await account.refresh();
    expect(account.profile?.userName, 'Mukul');
    expect(account.funds, isNull);
    expect(account.fundsClosed, isTrue);
    expect(account.fundsError, upstoxFundsHoursMessage);
    expect(account.ordersError, isNull);
    expect(account.positionsError, isNull);
    expect(account.profileError, isNull);
    expect(account.error, isNull);
    expect(account.countIn(UpstoxOrderGroup.pending), 1);
    expect(account.positions, hasLength(1));
    expect(account.linkState, UpstoxLinkState.connected);
    expect(account.displayFundsError, upstoxFundsHoursMessage);
  });

  test('invalid Upstox token marks link as invalid', () async {
    final auth = UpstoxController(
      tokenExchanger: ({
        required code,
        required apiKey,
        required apiSecret,
        required redirectUrl,
      }) async {
        return {'access_token': 'token', 'user_id': 'FS1042'};
      },
    );
    await auth.exchangeCode(0, 'code');
    Future<dynamic> request({
      required String method,
      required String path,
      Map<String, dynamic>? body,
      required bool roundRobin,
      String? baseUrl,
    }) async {
      throw Exception('Invalid token used to access API');
    }

    final account = UpstoxAccountController(auth: auth, requester: request);
    await account.refresh();
    expect(account.linkState, UpstoxLinkState.invalid);
    expect(account.displayOrdersError, isNull);
    expect(account.displayFundsError, isNull);
    expect(account.displayProfileError, isNull);
    expect(account.displayPositionsError, isNull);
  });

  test('fetches Upstox historical candles', () async {
    final auth = UpstoxController(
      tokenExchanger: ({
        required code,
        required apiKey,
        required apiSecret,
        required redirectUrl,
      }) async {
        return {'access_token': 'token', 'user_id': 'FS1042'};
      },
    );
    await auth.exchangeCode(0, 'code');
    String? requested;
    Future<dynamic> request({
      required String method,
      required String path,
      Map<String, dynamic>? body,
      required bool roundRobin,
      String? baseUrl,
    }) async {
      requested = path;
      return {
        'candles': [
          ['2026-09-12T09:15:00+05:30', 2880, 2890, 2875, 2885, 100],
          ['2026-09-12T09:16:00+05:30', 2885, 2892, 2882, 2890, 80],
        ],
      };
    }

    final account = UpstoxAccountController(auth: auth, requester: request);
    final candles = await account.fetchCandles(
      instrumentKey: 'NSE_EQ|INE002A01018',
      range: ChartRange.m1,
    );
    expect(
      requested,
      '/historical-candle/intraday/NSE_EQ%7CINE002A01018/minutes/1',
    );
    expect(candles, hasLength(2));
    expect(candles.last.close, 2890);
  });
}
