import 'package:flutter_test/flutter_test.dart';
import 'package:odin_trader/data/scrip_catalog.dart';
import 'package:odin_trader/data/scrip_master_parser.dart';
import 'package:odin_trader/state/scrip_master_controller.dart';

void main() {
  test('parses cash equity, index, futures and options', () {
    final now = DateTime(2026, 9, 12);
    const header = [
      'nMarketSegmentId',
      'nToken',
      'sSymbol',
      'sSeries',
      'sInstrumentName',
      'ExpiryDate',
      'nStrikePrice',
      'sOptionType',
      'sISINCode',
      'sSecurityDesc',
      'cDeleteFlag',
    ];
    final cash = [
      header,
      [
        1,
        2885,
        'RELIANCE',
        'EQ',
        'EQUITIES',
        '',
        0,
        '',
        'INE002A01018',
        'RELIANCE INDUSTRIES LTD',
        'N',
      ],
      [
        1,
        26000,
        'NIFTY',
        'EQ',
        'EQUITIES',
        '',
        0,
        '',
        '',
        'Nifty 50',
        'N',
      ],
      [
        1,
        99,
        'OLD BOND',
        'N0',
        'EQUITIES',
        '',
        0,
        '',
        'INE123',
        'Bond',
        'N',
      ],
    ];
    final fo = [
      header,
      [
        2,
        111,
        'NIFTY',
        'FUTIDX',
        'FUTIDX',
        '29-09-2026',
        -1,
        'XX',
        '',
        'NIFTY',
        'N',
      ],
      [
        2,
        222,
        'NIFTY',
        'OPTIDX',
        'OPTIDX',
        '29-09-2026',
        2500000,
        'CE',
        '',
        'NIFTY',
        'N',
      ],
      [
        2,
        333,
        'NIFTY',
        'OPTIDX',
        'OPTIDX',
        '08-09-2026',
        2400000,
        'PE',
        '',
        'NIFTY',
        'N',
      ],
    ];

    final equities = parseScripMasterMatrix(cash, derivatives: false, now: now);
    expect(equities.map((item) => item.symbol), ['RELIANCE', 'NIFTY']);
    expect(equities.first.kind, ScripKind.equity);
    expect(equities.first.isin, 'INE002A01018');
    expect(equities.last.kind, ScripKind.idx);

    final derivatives = parseScripMasterMatrix(fo, derivatives: true, now: now);
    expect(derivatives, hasLength(2));
    expect(derivatives.first.kind, ScripKind.future);
    expect(derivatives.first.displaySymbol, 'NIFTY 29-09-2026 FUT');
    expect(derivatives.last.kind, ScripKind.option);
    expect(derivatives.last.displaySymbol, 'NIFTY 29-09-2026 25000 CE');
  });

  test('search returns index, futures and options', () {
    final master = ScripMasterController(
      initialItems: const [
        ScripInfo(
          symbol: 'NIFTY',
          name: 'Nifty 50',
          token: '1_26000',
          kind: ScripKind.idx,
        ),
        ScripInfo(
          symbol: 'NIFTY',
          name: 'NIFTY',
          token: '2_111',
          kind: ScripKind.future,
          expiry: '29-09-2026',
        ),
        ScripInfo(
          symbol: 'NIFTY',
          name: 'NIFTY',
          token: '2_222',
          kind: ScripKind.option,
          expiry: '29-09-2026',
          optionType: 'CE',
          strike: 25000,
        ),
        ScripInfo(symbol: 'ICICIBANK', name: 'ICICI Bank', token: '1_4963'),
      ],
    );

    expect(
      master.search(query: '').map((item) => item.kind),
      containsAll([ScripKind.idx, ScripKind.equity]),
    );
    expect(
      master.search(query: 'NIFTY', kind: ScripKind.future).single.token,
      '2_111',
    );
    expect(
      master.search(query: 'NIFTY 25000 CE').single.displaySymbol,
      'NIFTY 29-09-2026 25000 CE',
    );
    expect(
      master.search(query: 'ICICI').map((item) => item.symbol),
      contains('ICICIBANK'),
    );
  });

  test('builds option chain strikes by expiry', () {
    final master = ScripMasterController();
    expect(master.hasOptionChain('NIFTY'), isTrue);
    expect(master.expiriesFor('NIFTY').first, '15-09-2026');
    expect(master.expiriesFor('NIFTY'), contains('29-09-2026'));
    final rows = master.chainFor('NIFTY', '29-09-2026');
    expect(
      rows.map((row) => row.strike),
      containsAll([24500.0, 24700.0, 24800.0, 25100.0]),
    );
    expect(rows.first.callToken, isNotNull);
    expect(rows.first.putToken, isNotNull);
    expect(master.byToken('1_2885')?.symbol, 'RELIANCE');
    expect(master.lookupSymbol('RELIANCE')?.token, '1_2885');
  });

  test('parses Upstox instrument files into the scrip master', () {
    final now = DateTime(2026, 9, 12);
    final items = parseUpstoxInstruments([
      {
        'instrument_key': 'NSE_EQ|INE002A01018',
        'instrument_type': 'EQ',
        'trading_symbol': 'RELIANCE',
        'name': 'Reliance Industries',
        'exchange': 'NSE',
        'isin': 'INE002A01018',
      },
      {
        'instrument_key': 'NSE_INDEX|Nifty 50',
        'instrument_type': 'INDEX',
        'trading_symbol': 'Nifty 50',
        'name': 'Nifty 50',
        'exchange': 'NSE',
      },
      {
        'instrument_key': 'NSE_FO|52567',
        'instrument_type': 'CE',
        'trading_symbol': 'NIFTY26SEP24800CE',
        'asset_symbol': 'NIFTY',
        'name': 'NIFTY',
        'exchange': 'NFO',
        'expiry': '2026-09-29',
        'strike_price': 24800,
      },
      {
        'instrument_key': 'NSE_FO|1',
        'instrument_type': 'CE',
        'trading_symbol': 'NIFTY25SEP24800CE',
        'asset_symbol': 'NIFTY',
        'expiry': '2025-09-25',
        'strike_price': 24800,
      },
    ], now: now);

    expect(items, hasLength(3));
    expect(items[0].kind, ScripKind.equity);
    expect(items[0].token, 'NSE_EQ|INE002A01018');
    expect(items[1].kind, ScripKind.idx);
    expect(items[1].symbol, 'NIFTY');
    expect(items[2].kind, ScripKind.option);
    expect(items[2].expiry, '29-09-2026');
    expect(items[2].strike, 24800);
    expect(parseExpiryDate('2026-09-29'), DateTime(2026, 9, 29));
    expect(parseExpiryDate('1789496999000'), DateTime(2026, 9, 15));
  });

  test('parses Upstox unix expiry timestamps for weekly options', () {
    final items = parseUpstoxInstruments([
      {
        'instrument_key': 'NSE_FO|50900',
        'instrument_type': 'CE',
        'trading_symbol': 'NIFTY 24800 CE 15 SEP 26',
        'underlying_symbol': 'NIFTY',
        'name': 'NIFTY',
        'exchange': 'NSE',
        'expiry': 1789496999000,
        'strike_price': 24800,
        'weekly': true,
      },
    ], now: DateTime(2026, 9, 12));

    expect(items.single.expiry, '15-09-2026');
    expect(items.single.symbol, 'NIFTY');
  });
}
