class OdinConfig {
  static const host = String.fromEnvironment(
    'ODIN_FEED_HOST',
    defaultValue: 'wave.bpwealth.com',
  );
  static const port = int.fromEnvironment(
    'ODIN_FEED_PORT',
    defaultValue: 4511,
  );
  static const useSsl = bool.fromEnvironment(
    'ODIN_FEED_SSL',
    defaultValue: true,
  );
  static const userId = String.fromEnvironment(
    'ODIN_FEED_USER_ID',
    defaultValue: 'TEST',
  );
  static const authKey = String.fromEnvironment(
    'ODIN_FEED_AUTH_KEY',
    defaultValue: '',
  );
  static const oiTag = String.fromEnvironment(
    'ODIN_OI_TAG',
    defaultValue: '88',
  );

  static const nseEqUrl = String.fromEnvironment(
    'NSE_EQ_URL',
    defaultValue:
        'https://odinscripmaster.s3.ap-south-1.amazonaws.com/scripfiles/v2/NSE_EQ.json',
  );
  static const bseEqUrl = String.fromEnvironment(
    'BSE_EQ_URL',
    defaultValue:
        'https://odinscripmaster.s3.ap-south-1.amazonaws.com/scripfiles/v2/BSE_EQ.json',
  );
  static const nseFoUrl = String.fromEnvironment(
    'NSE_FO_URL',
    defaultValue:
        'https://odinscripmaster.s3.ap-south-1.amazonaws.com/scripfiles/v2/NSE_FO.json',
  );
  static const bseFoUrl = String.fromEnvironment(
    'BSE_FO_URL',
    defaultValue:
        'https://odinscripmaster.s3.ap-south-1.amazonaws.com/scripfiles/v2/BSE_FO.json',
  );

  static const scripMasterUrls = <String, String>{
    'NSE_EQ': nseEqUrl,
    'BSE_EQ': bseEqUrl,
    'NSE_FO': nseFoUrl,
    'BSE_FO': bseFoUrl,
  };
}
