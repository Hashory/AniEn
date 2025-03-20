import 'dart:convert';

Map<String, dynamic> timelineStructureJson() {
  // 複数行のJSON文字列をトリプルクォーテーションで記述
  String jsonString = '''
{
	"version": "1.0",
	"timeline": {
		"role": "folder",
		"start": 0,
		"length": 72,
		"tracks": [
			{
				"role": "track",
				"track_role": "image",
				"name": "Aセル",
				"clips": [
					{
						"role": "clip",
						"start": 24,
						"length": 48,
						"source": "character.png"
					}
				]
			},
			{
				"role": "track",
				"track_role": "image",
				"name": "Bセル",
				"clips": [
					{
						"role": "clip",
						"start": 0,
						"length": 24,
						"source": "background.png"
					},
					{
						"role": "clip",
						"start": 25,
						"length": 72,
						"source": "background.png"
					}
				]
			},
			{
				"role": "track",
				"track_role": "",
				"name": "Cセル",
				"clips": [
					{
						"role": "folder",
						"start": 0,
						"length": 24,
						"tracks": [
							{
								"role": "track",
								"track_role": "",
								"name": "B1",
								"clips": [
									{
										"role": "clip",
										"start": 0,
										"length": 24,
										"source": "character.png"
										
									}
								]
							},
							{
								"role": "track",
								"track_role": "",
								"name": "B2",
								"clips": [
									{
										"role": "clip",
										"start": 25,
										"length": 24,
										"source": "background.png"
									}
								]
							}
						]
					},
					{
						"role": "folder",
						"start": 0,
						"length": 24,
						"tracks": [
							{
								"role": "track",
								"track_role": "",
								"name": "B1",
								"clips": [
									{
										"role": "clip",
										"start": 0,
										"length": 24,
										"source": "character.png"
									}
								]
							},
							{
								"role": "track",
								"track_role": "",
								"name": "B2",
								"clips": [
									{
										"role": "clip",
										"start": 25,
										"length": 24,
										"source": "background.png"
									}
								]
							}
						]
					}
				]
			}
		]
	}
}
  ''';

  // jsonDecodeで文字列をMapに変換して返す
  return jsonDecode(jsonString);
}
