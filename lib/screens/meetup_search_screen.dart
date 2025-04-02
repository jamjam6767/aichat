import 'package:flutter/material.dart';
import '../models/meetup.dart';
import '../services/meetup_service.dart';

class MeetupSearchScreen extends StatefulWidget {
  const MeetupSearchScreen({Key? key}) : super(key: key);

  @override
  State<MeetupSearchScreen> createState() => _MeetupSearchScreenState();
}

class _MeetupSearchScreenState extends State<MeetupSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MeetupService _meetupService = MeetupService();
  String _searchQuery = '';
  bool _isLoading = false;
  List<Meetup> _searchResults = [];
  
  // 검색 필터 옵션
  String? _selectedDay;
  final List<String> _dayOptions = ['전체', '월', '화', '수', '목', '금', '토', '일'];
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 검색 실행 함수
  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 모임 서비스를 통해 검색 실행
      final results = await _meetupService.searchMeetups(_searchQuery, dayFilter: _selectedDay);
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('모임 검색'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 검색 입력 영역
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 검색창
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '모임 이름, 장소, 내용으로 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSubmitted: (_) {
                    _performSearch();
                  },
                ),
                
                const SizedBox(height: 12),
                
                // 필터 영역 (요일 필터)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('요일: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      ..._dayOptions.map((day) {
                        final isSelected = _selectedDay == day || 
                                          (_selectedDay == null && day == '전체');
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(day),
                            selected: isSelected,
                            selectedColor: Colors.blue[100],
                            onSelected: (selected) {
                              setState(() {
                                _selectedDay = day == '전체' ? null : day;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 검색 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _searchQuery.isNotEmpty ? _performSearch : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('검색하기'),
                  ),
                ),
              ],
            ),
          ),
          
          // 검색 결과 영역
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty 
                                  ? Icons.search 
                                  : Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? '검색어를 입력하세요'
                                  : '검색 결과가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final meetup = _searchResults[index];
                          return MeetupCard(meetup: meetup);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// 모임 카드 위젯 (검색 결과 표시용)
class MeetupCard extends StatelessWidget {
  final Meetup meetup;
  
  const MeetupCard({Key? key, required this.meetup}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          meetup.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(meetup.description),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  meetup.location,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${_getFormattedDate(meetup.date)} ${meetup.time}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.group,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '${meetup.participants.length}/${meetup.maxParticipants}명',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '주최: ${meetup.hostName}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // 모임 상세 페이지로 이동
        },
      ),
    );
  }
  
  // 날짜 포맷 함수
  String _getFormattedDate(DateTime date) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}/${date.day}($weekday)';
  }
}