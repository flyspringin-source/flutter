const upstoxRedirectUrl = 'https://www.flyspring.in/api/setToken';

const upstoxDefaultApiKeys = [
  '64bcafc6-5965-46c3-9e9b-113e396b1ecb',
  '15b39ed0-f0b0-4e16-9948-80a46f62e295',
  '6cfc3a27-df0f-4aa8-9e33-7b8bc20b255b',
  '7b717ec7-2cd4-4ff8-b852-de03162a80f1',
  'a34aec7f-b199-4fc7-b0a3-ee965b61d9e1',
  'dc03b0e3-8e74-4bb5-89b4-5906c33d0343',
];

const upstoxDefaultApiSecrets = [
  'v4d0xp6cy3',
  'pe3ihrm4kw',
  'nyukt3ypxc',
  'u7qs0lh0g6',
  '4puy3lz9v6',
  'vd15mfdj8o',
];

const upstoxAuthorizeUrl =
    'https://api.upstox.com/v2/login/authorization/dialog';
const upstoxTokenUrl = 'https://api.upstox.com/v2/login/authorization/token';
const upstoxApiBase = 'https://api.upstox.com/v2';
const upstoxApiV3 = 'https://api.upstox.com/v3';
const upstoxHftOrderBase = 'https://api-hft.upstox.com/v2';
const upstoxPlaceOrderUrl = '$upstoxHftOrderBase/order/place';

const upstoxInstrumentFiles = {
  'ALL':
      'https://assets.upstox.com/market-quote/instruments/exchange/complete.json.gz',
};
