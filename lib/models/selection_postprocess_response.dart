class SelectionPostprocessResponse {
  final String message;
  final String result;
  SelectionPostprocessResponse({
    required this.message,
    required this.result,
  });
  factory SelectionPostprocessResponse.fromJson(Map<String, dynamic> json) {
    return SelectionPostprocessResponse(
      message: json['message'] ?? '',
      result: json['result'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'result': result,
    };
  }
}