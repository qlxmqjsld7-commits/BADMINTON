import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase 연결 실패: $e");
  }
  runApp(const BadmintonEmpireApp());
}

// --- 공통 설정 및 등급 색상 ---
final List<IconData> clubIcons = [
  Icons.sports_tennis, Icons.fitness_center, Icons.workspace_premium,
  Icons.military_tech, Icons.bolt, Icons.emoji_events,
  Icons.shield, Icons.star, Icons.local_fire_department,
  Icons.groups, Icons.flag, Icons.auto_awesome,
];

Color getLevelColor(String? level) {
  switch (level) {
    case 'S': return Colors.black;
    case 'A': return Colors.red;
    case 'B': return Colors.green;
    case 'C': return Colors.blue;
    case 'D': return Colors.yellow;
    case '초심': return Colors.pinkAccent;
    case '왕초심': return Colors.grey;
    default: return Colors.white;
  }
}

Color getLevelTextColor(String? level) {
  if (level == 'S' || level == 'A' || level == 'C') return Colors.white;
  return Colors.black;
}

class BadmintonEmpireApp extends StatelessWidget {
  const BadmintonEmpireApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
    home: const ClubSelectionPage(),
  );
}

// --- 1. 클럽 선택 페이지 ---
class ClubSelectionPage extends StatefulWidget {
  const ClubSelectionPage({super.key});
  @override
  State<ClubSelectionPage> createState() => _ClubSelectionPageState();
}

class _ClubSelectionPageState extends State<ClubSelectionPage> {
  String _keyword = "";
  final String _instaLink = 'https://www.instagram.com/qlxmqjsld7/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🏸 게임 중인 클럽"),
        actions: [IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Colors.pink), onPressed: () => launchUrl(Uri.parse(_instaLink)))],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          onChanged: (v) => setState(() => _keyword = v),
          decoration: const InputDecoration(hintText: "클럽명을 입력하소서...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
        )),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['name'].toString().contains(_keyword)).toList();
            return ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) {
              final club = list[i].data() as Map<String, dynamic>;
              return ListTile(
                leading: Icon(IconData(club['iconCode'] ?? Icons.shield.codePoint, fontFamily: 'MaterialIcons'), color: Colors.indigo),
                title: Text(club['name'] ?? ""),
                onTap: () => _enterClub(club['name'], club['password'], club['adminPassword']),
              );
            });
          },
        ))
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addClub, label: const Text("클럽 생성"), icon: const Icon(Icons.add)),
    );
  }

  void _enterClub(String name, String pass, String? adminPass) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("$name 입장"),
      actions: [
        TextButton(onPressed: () { Navigator.pop(ctx); _pw(name, adminPass ?? "", true); }, child: const Text("운영진")),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _pw(name, pass, false); }, child: const Text("회원")),
      ],
    ));
  }

  void _pw(String name, String correct, bool isAdmin) {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(isAdmin ? "운영진 인증" : "회원 인증"),
      content: TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: "비밀번호")),
      actions: [ElevatedButton(onPressed: () {
        if (c.text == correct) {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(builder: (_) => MainNav(isAdmin: isAdmin, clubName: name)));
        }
      }, child: const Text("확인"))],
    ));
  }

  void _addClub() {
    final nC = TextEditingController(); final pC = TextEditingController(); final aC = TextEditingController();
    int selectedIconCode = Icons.shield.codePoint;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => AlertDialog(
      title: const Text("모임 만들기"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: "클럽 이름")),
        TextField(controller: pC, obscureText: true, decoration: const InputDecoration(labelText: "회원 비번")),
        TextField(controller: aC, obscureText: true, decoration: const InputDecoration(labelText: "운영진 비번")),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: clubIcons.map((icon) => GestureDetector(onTap: () => setS(() => selectedIconCode = icon.codePoint), child: Icon(icon, color: selectedIconCode == icon.codePoint ? Colors.indigo : Colors.grey))).toList()),
      ])),
      actions: [ElevatedButton(onPressed: () async {
        if(nC.text.isNotEmpty) {
          final now = DateTime.now();
          await FirebaseFirestore.instance.collection('clubs').doc(nC.text).set({
            'name': nC.text, 'password': pC.text, 'adminPassword': aC.text,
            'iconCode': selectedIconCode,
            'expireAt': now.add(const Duration(hours: 4)).millisecondsSinceEpoch,
            'canExtend': true, // 🔴 생성 시 연장 가능 상태로 시작
          });
          if (mounted) Navigator.pop(ctx);
        }
      }, child: const Text("만들기"))],
    )));
  }
}

// --- 2. 메인 네비게이션 (🛡️ 1회 연장 제한 시스템) ---
class MainNav extends StatefulWidget {
  final bool isAdmin; final String clubName;
  const MainNav({super.key, required this.isAdmin, required this.clubName});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || !snap.data!.exists) return const SizedBox();
            final data = snap.data!.data() as Map<String, dynamic>;
            final int expireAt = data['expireAt'] ?? 0;
            final bool canExtend = data['canExtend'] ?? true; // 🔴 연장 가능 여부 확인

            return StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (ctx, _) {
                final remain = expireAt - DateTime.now().millisecondsSinceEpoch;
                if (remain <= 0) {
                  FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).delete();
                  Future.delayed(Duration.zero, () { if (mounted) Navigator.popUntil(context, (r) => r.isFirst); });
                  return Container(color: Colors.red, child: const Center(child: Text("만료됨", style: TextStyle(color: Colors.white))));
                }
                final min = (remain / 1000 / 60).floor();
                final sec = ((remain / 1000) % 60).floor();

                final bool isUnder10Min = remain <= (10 * 60 * 1000);

                // 🛡️ 10분이 넘게 남았다면 다시 연장 가능 상태로 초기화 (4시간 후 다시 연장 가능하게 함)
                if (!isUnder10Min && !canExtend) {
                  FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).update({'canExtend': true});
                }

                return Container(
                  color: min < 10 ? Colors.red : Colors.indigo[900],
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Padding(padding: const EdgeInsets.only(left: 10), child: Text(min < 10 ? "⚠️ 종료 임박: $min분 $sec초" : "⏳ 남은시간: $min분 $sec초", style: const TextStyle(color: Colors.white, fontSize: 11))),

                    // 🛡️ 운영진 + 10분 이내 + 아직 연장하지 않은 상태일 때만 버튼 노출
                    if (widget.isAdmin && isUnder10Min && canExtend)
                      TextButton(onPressed: () {
                        FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).update({
                          'expireAt': expireAt + (4 * 3600 * 1000),
                          'canExtend': false, // 🔴 누르는 즉시 이번 사이클 연장권 소멸
                        });
                      }, child: const Text("4시간 연장", style: TextStyle(color: Colors.yellow, fontSize: 11, fontWeight: FontWeight.bold))),
                  ]),
                );
              },
            );
          },
        ),
      ),
      body: [PlayerList(isAdmin: widget.isAdmin, clubName: widget.clubName), MatchPage(isAdmin: widget.isAdmin, clubName: widget.clubName)][_idx],
      bottomNavigationBar: BottomNavigationBar(currentIndex: _idx, onTap: (i) => setState(() => _idx = i), items: const [
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "선수 명단"), BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "대진표"),
      ]),
    );
  }
}

// --- 3. 선수 명단 (동일) ---
class PlayerList extends StatefulWidget {
  final bool isAdmin; final String clubName;
  const PlayerList({super.key, required this.isAdmin, required this.clubName});
  @override
  State<PlayerList> createState() => _PlayerListState();
}

class _PlayerListState extends State<PlayerList> {
  String _search = "";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("선수 명단")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: TextField(onChanged: (v)=>setState(()=>_search=v), decoration: const InputDecoration(hintText: "활동명 검색...", prefixIcon: Icon(Icons.search)))),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).collection('players').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs.where((d) => (d.data() as Map<String, dynamic>)['name'].toString().contains(_search)).toList();
            return ListView.builder(itemCount: docs.length, itemBuilder: (ctx, i) {
              final p = docs[i].data() as Map<String, dynamic>;
              final String pName = p['name'] ?? "";
              final String level = p['level'] ?? "초심";
              final sub = p['shuttleSubmitted'] ?? false;
              final conf = p['shuttleConfirmed'] ?? false;
              final bool isLocked = conf && !widget.isAdmin;
              final int gCount = p['gameCount'] ?? 0;

              return ListTile(
                onLongPress: widget.isAdmin ? () => docs[i].reference.delete() : null,
                leading: CircleAvatar(backgroundColor: getLevelColor(level), child: Text(level, style: TextStyle(fontSize: 10, color: getLevelTextColor(level)))),
                title: Text("$pName ($gCount회)"),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (!widget.isAdmin) const Text("셔틀콕제출확인", style: TextStyle(fontSize: 8, color: Colors.grey)),
                    if (widget.isAdmin) Text(sub ? "셔틀콕 본인제출" : "미제출", style: TextStyle(fontSize: 8, color: sub ? Colors.orange : Colors.grey)),
                    if (widget.isAdmin) Text(conf ? "셔틀콕운영진확인" : "미확인", style: TextStyle(fontSize: 8, color: conf ? Colors.green : Colors.grey)),
                  ]),
                  Checkbox(value: sub, activeColor: Colors.orange, onChanged: isLocked ? null : (v) => docs[i].reference.update({'shuttleSubmitted': v, 'shuttleConfirmed': false})),
                  if (widget.isAdmin) IconButton(icon: Icon(conf ? Icons.verified : Icons.verified_outlined, color: conf ? Colors.green : Colors.grey), onPressed: () => docs[i].reference.update({'shuttleConfirmed': !conf})),
                ]),
              );
            });
          },
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add), label: const Text("선수 등록")),
    );
  }

  void _add() {
    final nC = TextEditingController(); String lv = "초심";
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: const Text("선수 등록"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: "활동명")),
        DropdownButton<String>(value: lv, items: ["S","A","B","C","D","초심","왕초심"].map((e)=>DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=>setS(()=>lv=v!)),
      ]),
      actions: [ElevatedButton(onPressed: () {
        if(nC.text.isNotEmpty) {
          FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).collection('players').add({'name':nC.text,'level':lv,'shuttleSubmitted':false,'shuttleConfirmed':false, 'gameCount': 0});
          Navigator.pop(ctx);
        }
      }, child: const Text("등록"))],
    )));
  }
}

// --- 4. 대진표 (동일) ---
class MatchPage extends StatelessWidget {
  final bool isAdmin; final String clubName;
  const MatchPage({super.key, required this.isAdmin, required this.clubName});

  @override
  Widget build(BuildContext context) {
    final matchDoc = FirebaseFirestore.instance.collection('all_matches').doc(clubName);

    return Scaffold(
      appBar: AppBar(title: const Text("대진 상황")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: matchDoc.snapshots(),
        builder: (context, snap) {
          final Map<String, dynamic> data = (snap.hasData && snap.data!.exists)
              ? snap.data!.data() as Map<String, dynamic>
              : _createDefaultMap();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').doc(clubName).collection('players').snapshots(),
            builder: (context, pSnap) {
              final players = pSnap.hasData ? pSnap.data!.docs : [];
              Map<String, String> pLv = {};
              Map<String, int> pCount = {};
              for (var d in players) {
                final dData = d.data() as Map<String, dynamic>;
                final String name = dData['name']?.toString() ?? "알수없음";
                pLv[name] = dData['level']?.toString() ?? "초심";
                pCount[name] = dData.containsKey('gameCount') ? (dData['gameCount'] ?? 0) : 0;
              }

              Set<String> busy = {};
              data.forEach((k, v) { if (v is List) { for (var n in v) { if (n != "선택") busy.add(n.toString()); } } });

              return ListView(padding: const EdgeInsets.all(10), children: [
                const Text("🏸 경기 중", style: TextStyle(fontWeight: FontWeight.bold)),
                GridView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.52, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: 4, itemBuilder: (ctx, i) {
                  final List list = List.from(data['court$i'] ?? ["선택", "선택", "선택", "선택"]);
                  final String st = data['state$i']?.toString() ?? "대기중";
                  return Container(
                    decoration: BoxDecoration(color: st=="게임중"?Colors.orange[800]:Colors.indigo[400], borderRadius: BorderRadius.circular(8)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      Text("${i+1}코트 [$st]", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      _row(ctx, list, 0, 1, 'court$i', pLv, pCount, players, busy, matchDoc),
                      const Text("VS", style: TextStyle(color: Colors.white, fontSize: 10)),
                      _row(ctx, list, 2, 3, 'court$i', pLv, pCount, players, busy, matchDoc),
                      if (isAdmin) ElevatedButton(onPressed: () => _toggle(i, st, list, matchDoc), child: Text(st=="대기중"?"시작":"종료", style: const TextStyle(fontSize: 10))),
                    ]),
                  );
                }
                ),
                const Divider(height: 30),
                const Text("⏳ 다음 대기", style: TextStyle(fontWeight: FontWeight.bold)),
                ...List.generate(3, (i) {
                  final List list = List.from(data['wait$i'] ?? ["선택", "선택", "선택", "선택"]);
                  return Card(child: Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    Text("${i+1}"),
                    _slot(context, list, 0, 'wait$i', pLv, pCount, players, busy, matchDoc), _slot(context, list, 1, 'wait$i', pLv, pCount, players, busy, matchDoc),
                    const Text("vs"),
                    _slot(context, list, 2, 'wait$i', pLv, pCount, players, busy, matchDoc), _slot(context, list, 3, 'wait$i', pLv, pCount, players, busy, matchDoc),
                    if (isAdmin) IconButton(icon: const Icon(Icons.login, color: Colors.indigo), onPressed: () => _moveToCourt(i, list, data, matchDoc)),
                  ])));
                })
              ]);
            },
          );
        },
      ),
    );
  }

  void _moveToCourt(int waitIdx, List waitPlayers, Map<String, dynamic> data, DocumentReference doc) {
    for (int i = 0; i < 4; i++) {
      final List courtList = List.from(data['court$i'] ?? ["선택", "선택", "선택", "선택"]);
      if (courtList.every((p) => p == "선택")) {
        doc.update({'court$i': waitPlayers, 'wait$waitIdx': ["선택", "선택", "선택", "선택"]});
        return;
      }
    }
  }

  Map<String, dynamic> _createDefaultMap() {
    Map<String, dynamic> clean = {};
    for(int i=0; i<4; i++) { clean['court$i'] = ["선택","선택","선택","선택"]; clean['state$i'] = "대기중"; }
    for(int i=0; i<3; i++) { clean['wait$i'] = ["선택","선택","선택","선택"]; }
    return clean;
  }

  Widget _row(BuildContext ctx, List list, int i1, int i2, String field, Map lv, Map count, List docs, Set<String> busy, DocumentReference doc) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _slot(ctx, list, i1, field, lv, count, docs, busy, doc),
      _slot(ctx, list, i2, field, lv, count, docs, busy, doc)
    ]);
  }

  Widget _slot(BuildContext ctx, List list, int idx, String field, Map lv, Map count, List docs, Set<String> busy, DocumentReference doc) {
    String name = (list.length > idx) ? list[idx].toString() : "선택";
    String currentLv = lv[name] ?? "";
    return InkWell(
      onTap: isAdmin ? () => _pick(ctx, docs, (v) {
        List newList = List.from(list);
        while (newList.length <= idx) { newList.add("선택"); }
        newList[idx] = v;
        doc.set({field: newList}, SetOptions(merge: true));
      }, busy) : null,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            if(name != "선택") CircleAvatar(radius: 7, backgroundColor: getLevelColor(currentLv), child: Text(currentLv, style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: getLevelTextColor(currentLv)))),
            const SizedBox(width: 4),
            Text(name=="선택"?"선택":"$name(${count[name]??0})", style: const TextStyle(color: Colors.white, fontSize: 9)),
          ])),
    );
  }

  void _toggle(int i, String st, List list, DocumentReference doc) async {
    if (st == "게임중") {
      for (var n in list) {
        if (n != "선택") {
          final q = await FirebaseFirestore.instance.collection('clubs').doc(clubName).collection('players').where('name', isEqualTo: n).get();
          if (q.docs.isNotEmpty) {
            q.docs.first.reference.update({'gameCount': FieldValue.increment(1)});
          }
        }
      }
    }
    doc.set({'state$i': st == "대기중" ? "게임중" : "대기중"}, SetOptions(merge: true));
  }

  void _pick(BuildContext ctx, List docs, Function(String) onP, Set<String> busy) {
    showModalBottomSheet(context: ctx, builder: (c) => ListView(children: [
      ListTile(title: const Text("비우기", style: TextStyle(color: Colors.red)), onTap: () { onP("선택"); Navigator.pop(c); }),
      ...docs.map((d) {
        final dData = d.data() as Map<String, dynamic>;
        final String name = dData['name'] ?? "";
        final String level = dData['level'] ?? "";
        final int count = dData.containsKey('gameCount') ? (dData['gameCount'] ?? 0) : 0;
        return ListTile(
          leading: CircleAvatar(backgroundColor: getLevelColor(level), child: Text(level, style: TextStyle(fontSize: 10, color: getLevelTextColor(level)))),
          title: Text("$name ($count회)"),
          enabled: !busy.contains(name),
          onTap: () { onP(name); Navigator.pop(c); },
        );
      })
    ]));
  }
}