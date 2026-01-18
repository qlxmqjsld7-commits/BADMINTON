import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase 연결 실패: $e");
  }
  runApp(const BadmintonEmpireApp());
}

class BadmintonEmpireApp extends StatelessWidget {
  const BadmintonEmpireApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
      home: const ClubSelectionPage(),
    );
  }
}

// --- 🛡️ 급수별 색상 및 텍스트 설정 ---
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
  if (level == 'S' || level == 'A' || level == 'C' || level == 'B') return Colors.white;
  return Colors.black;
}

// --- 1. 클럽 선택 ---
class ClubSelectionPage extends StatefulWidget {
  const ClubSelectionPage({super.key});
  @override
  State<ClubSelectionPage> createState() => _ClubSelectionPageState();
}

class _ClubSelectionPageState extends State<ClubSelectionPage> {
  String _keyword = "";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏸 클럽 검색")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          onChanged: (v) => setState(() => _keyword = v),
          decoration: const InputDecoration(hintText: "클럽명 입력...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
        )),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!.docs.where((d) => d.get('name').toString().contains(_keyword)).toList();
            return ListView.builder(itemCount: list.length, itemBuilder: (ctx, i) {
              final club = list[i].data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.shield, color: Colors.indigo),
                title: Text(club['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _enterClub(club['name'], club['password']),
              );
            });
          },
        ))
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _addClub, child: const Icon(Icons.add)),
    );
  }

  void _addClub() {
    final nC = TextEditingController(); final pC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("새 클럽 등록"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: "클럽명")),
        TextField(controller: pC, obscureText: true, decoration: const InputDecoration(labelText: "암호")),
      ]),
      actions: [ElevatedButton(onPressed: () async {
        if(nC.text.isNotEmpty) {
          await FirebaseFirestore.instance.collection('clubs').doc(nC.text).set({'name': nC.text, 'password': pC.text});
          if (!mounted) return;
          Navigator.pop(ctx);
        }
      }, child: const Text("등록"))],
    ));
  }

  void _enterClub(String name, String pass) {
    final c = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("$name 입장"),
      content: TextField(controller: c, obscureText: true, decoration: const InputDecoration(labelText: "비밀번호")),
      actions: [ElevatedButton(onPressed: () {
        if(c.text == pass) { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => MainNav(isAdmin: true, clubName: name))); }
      }, child: const Text("확인"))],
    ));
  }
}

// --- 2. 입장 모드 ---
class EntrancePage extends StatelessWidget {
  final String clubName;
  const EntrancePage({super.key, required this.clubName});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(clubName)),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton.icon(style: ElevatedButton.styleFrom(minimumSize: const Size(200, 60)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MainNav(isAdmin: true, clubName: clubName))), icon: const Icon(Icons.admin_panel_settings), label: const Text("🛡️ 운영진 입장")),
        const SizedBox(height: 20),
        OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(200, 60)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MainNav(isAdmin: false, clubName: clubName))), icon: const Icon(Icons.person), label: const Text("🏸 회원 입장")),
      ])),
    );
  }
}

// --- 3. 메인 네비게이션 ---
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
      body: [PlayerList(isAdmin: widget.isAdmin, clubName: widget.clubName), MatchPage(isAdmin: widget.isAdmin, clubName: widget.clubName)][_idx],
      bottomNavigationBar: BottomNavigationBar(currentIndex: _idx, onTap: (i) => setState(() => _idx = i), items: const [
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "선수"),
        BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: "대진표"),
      ]),
    );
  }
}

// --- 4. 선수 명단 ---
class PlayerList extends StatefulWidget {
  final bool isAdmin; final String clubName;
  const PlayerList({super.key, required this.isAdmin, required this.clubName});
  @override
  State<PlayerList> createState() => _PlayerListState();
}

class _PlayerListState extends State<PlayerList> {
  Offset _btnPos = const Offset(20, 20);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("선수 명단"), backgroundColor: Colors.indigo[50]),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).collection('players').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return ListView.builder(itemCount: docs.length, itemBuilder: (ctx, i) {
                final p = docs[i].data() as Map<String, dynamic>;
                bool self = p['selfReport'] ?? false;
                bool admin = p['adminConfirm'] ?? false;
                String lv = p['level'] ?? "초심";
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(backgroundColor: getLevelColor(lv), child: Text(lv, style: TextStyle(fontSize: 10, color: getLevelTextColor(lv), fontWeight: FontWeight.bold))),
                  title: Text(p['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(admin ? "✅ 확인완료" : (self ? "⚠️ 대기중" : "❌ 미제출"), style: TextStyle(fontSize: 11, color: admin ? Colors.green : (self ? Colors.orange : Colors.red))),
                  trailing: SizedBox(width: 135, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    _checkColumn("콕제출 본인", self, (v) => docs[i].reference.update({'selfReport': v}), true),
                    const SizedBox(width: 5),
                    _checkColumn("콕제출 운영자", admin, (v) => docs[i].reference.update({'adminConfirm': v}), widget.isAdmin),
                  ])),
                );
              });
            },
          ),
          Positioned(
            right: _btnPos.dx, bottom: _btnPos.dy,
            child: Draggable(
              feedback: _btnWidget(opacity: 0.5),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  double newX = MediaQuery.of(context).size.width - details.offset.dx - 120;
                  double newY = MediaQuery.of(context).size.height - details.offset.dy - 80;
                  _btnPos = Offset(newX.clamp(10, 300), newY.clamp(10, 700));
                });
              },
              child: _btnWidget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btnWidget({double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: ElevatedButton.icon(
        onPressed: () => _addP(context),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, elevation: 8, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        icon: const Icon(Icons.how_to_reg), label: const Text("선수 등록", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _checkColumn(String title, bool val, Function(bool?) onChg, bool enabled) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
      SizedBox(height: 30, width: 30, child: Checkbox(value: val, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: enabled ? onChg : null, activeColor: title.contains("운영자") ? Colors.green : Colors.orange)),
    ]);
  }

  void _addP(BuildContext ctx) {
    final nC = TextEditingController(); String lv = "초심";
    showDialog(context: ctx, builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
      title: const Text("선수 등록"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nC, decoration: const InputDecoration(labelText: "이름")),
        DropdownButton<String>(value: lv, isExpanded: true, items: ["S","A","B","C","D","초심","왕초심"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setS(() => lv = v!)),
      ]),
      actions: [ElevatedButton(onPressed: () {
        if(nC.text.isNotEmpty) {
          FirebaseFirestore.instance.collection('clubs').doc(widget.clubName).collection('players').add({'name': nC.text, 'level': lv, 'selfReport': false, 'adminConfirm': false});
          Navigator.pop(c);
        }
      }, child: const Text("등록"))],
    )));
  }
}

// --- 5. 대진 상황 (휘장 추가됨) ---
class MatchPage extends StatelessWidget {
  final bool isAdmin; final String clubName;
  const MatchPage({super.key, required this.isAdmin, required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("대진 상황")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').doc(clubName).collection('status').doc('matches').snapshots(),
        builder: (context, snap) {
          final data = (snap.hasData && snap.data!.exists) ? snap.data!.data() as Map<String, dynamic> : <String, dynamic>{};
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('clubs').doc(clubName).collection('players').snapshots(),
            builder: (context, pSnap) {
              final playersDocs = pSnap.hasData ? pSnap.data!.docs : [];
              // 선수 정보를 맵으로 변환하여 이름으로 등급을 즉시 찾게 함
              Map<String, String> pLevels = {};
              for (var d in playersDocs) {
                var p = d.data() as Map<String, dynamic>;
                pLevels[p['name']] = p['level'] ?? "초심";
              }

              Set<String> busy = {};
              for (int k=0; k<4; k++) {
                List cList = data['court$k'] ?? [];
                for (var p in cList) if (p != "선택" && p != "대기") busy.add(p);
                List wList = data['wait$k'] ?? [];
                for (var p in wList) if (p != "선택" && p != "대기") busy.add(p);
              }

              return Column(children: [
                Expanded(flex: 3, child: GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: 4, itemBuilder: (ctx, i) => _courtCard(ctx, i, data, playersDocs, busy, pLevels))),
                const Divider(thickness: 2),
                const Text("대기 중인 대진 (4개)", style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(flex: 2, child: ListView.builder(itemCount: 4, itemBuilder: (ctx, i) => _waitBar(ctx, i, data, playersDocs, busy, pLevels))),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _courtCard(BuildContext ctx, int i, Map<String, dynamic> data, List playersDocs, Set<String> busy, Map<String, String> pLevels) {
    final List court = data['court$i'] ?? ["선택", "선택", "선택", "선택"];
    final String status = data['status$i'] ?? "대기중";
    Color cardColor = status == "경기중" ? Colors.red[900]! : (status == "경기종료" ? Colors.blueGrey[800]! : Colors.green[800]!);
    return Card(color: cardColor, child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("${i+1}코트", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        if(isAdmin) InkWell(onTap: () => _updateMatch({'status$i': status == "대기중" ? "경기중" : "대기중"}), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: Text(status, style: TextStyle(fontSize: 10, color: cardColor, fontWeight: FontWeight.bold)))) else Text("($status)", style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_slot(ctx, i, 0, court, playersDocs, busy, 'court$i', pLevels), _slot(ctx, i, 1, court, playersDocs, busy, 'court$i', pLevels)]),
      const Text("VS", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 12)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_slot(ctx, i, 2, court, playersDocs, busy, 'court$i', pLevels), _slot(ctx, i, 3, court, playersDocs, busy, 'court$i', pLevels)]),
      if(isAdmin) ElevatedButton(onPressed: () => _updateMatch({'status$i': "경기종료"}), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, minimumSize: const Size(70, 25)), child: const Text("경기종료", style: TextStyle(fontSize: 10, color: Colors.black))),
    ]));
  }

  Widget _waitBar(BuildContext ctx, int idx, Map<String, dynamic> data, List playersDocs, Set<String> busy, Map<String, String> pLevels) {
    final List wait = data['wait$idx'] ?? ["대기", "대기", "대기", "대기"];
    return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: Colors.indigo[50], child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
      Text("대기${idx+1}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_slot(ctx, idx, 0, wait, playersDocs, busy, 'wait$idx', pLevels), _slot(ctx, idx, 1, wait, playersDocs, busy, 'wait$idx', pLevels), const Text("vs"), _slot(ctx, idx, 2, wait, playersDocs, busy, 'wait$idx', pLevels), _slot(ctx, idx, 3, wait, playersDocs, busy, 'wait$idx', pLevels)])),
      if(isAdmin) IconButton(icon: const Icon(Icons.send, size: 20), onPressed: () => _showDeployDialog(ctx, idx, data)),
    ])));
  }

  // --- 👑 휘장이 추가된 슬롯 디자인 ---
  Widget _slot(BuildContext ctx, int cIdx, int sIdx, List list, List playersDocs, Set<String> busy, String field, Map<String, String> pLevels) {
    String name = list[sIdx];
    String? lv = pLevels[name]; // 이름으로 급수 검색
    bool isCourt = field.startsWith('court');

    return InkWell(
      onTap: isAdmin ? () => _pickPlayerWithSearch(ctx, playersDocs, busy, name, (val) { list[sIdx] = val; _updateMatch({field: list}); }) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lv != null) // 등록된 선수인 경우 급수 휘장 표시
              Container(
                width: 14, height: 14, margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: getLevelColor(lv), shape: BoxShape.circle),
                child: Center(child: Text(lv[0], style: TextStyle(fontSize: 8, color: getLevelTextColor(lv), fontWeight: FontWeight.bold))),
              ),
            Text(name, style: TextStyle(color: isCourt ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _pickPlayerWithSearch(BuildContext ctx, List playersDocs, Set<String> busy, String cur, Function(String) onPick) {
    String searchTxt = "";
    showModalBottomSheet(context: ctx, isScrollControlled: true, builder: (c) => StatefulBuilder(builder: (ctx2, setS) {
      final filtered = playersDocs.where((p) => (p.data() as Map<String, dynamic>)['name'].toString().contains(searchTxt)).toList();
      return Container(height: MediaQuery.of(ctx).size.height * 0.8, padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(decoration: const InputDecoration(hintText: "선수 이름 검색...", prefixIcon: Icon(Icons.search)), onChanged: (v) => setS(() => searchTxt = v)),
        const SizedBox(height: 10),
        ListTile(title: const Text("❌ 선수 제거", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onTap: () { onPick(cur.contains('대기') ? "대기" : "선택"); Navigator.pop(c); }),
        const Divider(),
        Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (ctx3, i) {
          final pData = filtered[i].data() as Map<String, dynamic>;
          String n = pData['name']; String lv = pData['level'] ?? "초심";
          bool isB = busy.contains(n) && n != cur;
          return ListTile(enabled: !isB, leading: CircleAvatar(backgroundColor: getLevelColor(lv), child: Text(lv, style: TextStyle(fontSize: 10, color: getLevelTextColor(lv), fontWeight: FontWeight.bold))), title: Text(n, style: TextStyle(color: isB ? Colors.grey : Colors.black)), subtitle: isB ? const Text("이미 투입됨") : null, onTap: () { onPick(n); Navigator.pop(c); });
        })),
      ]));
    }));
  }

  void _updateMatch(Map<String, dynamic> map) {
    FirebaseFirestore.instance.collection('clubs').doc(clubName).collection('status').doc('matches').set(map, SetOptions(merge: true));
  }

  void _showDeployDialog(BuildContext ctx, int wIdx, Map<String, dynamic> data) {
    showDialog(context: ctx, builder: (c) => AlertDialog(title: const Text("투입 코트 선택"), actions: List.generate(4, (i) {
      String s = data['status$i'] ?? "대기중"; bool can = (s != "경기중");
      return ElevatedButton(onPressed: can ? () {
        FirebaseFirestore.instance.collection('clubs').doc(clubName).collection('status').doc('matches').set({'court$i': List.from(data['wait$wIdx']), 'wait$wIdx': ["대기", "대기", "대기", "대기"], 'status$i': "경기중"}, SetOptions(merge: true));
        Navigator.pop(c);
      } : null, child: Text("${i+1}코트($s)"));
    })));
  }
}