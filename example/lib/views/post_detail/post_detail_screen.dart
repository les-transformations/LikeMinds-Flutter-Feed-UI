import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:likeminds_feed/likeminds_feed.dart';
import 'package:likeminds_feed_ui_fl/likeminds_feed_ui_fl.dart';
import 'package:lm_feed_ui_example/services/likeminds_service.dart';
import 'package:lm_feed_ui_example/services/service_locator.dart';
import 'package:lm_feed_ui_example/utils/constants/ui_constants.dart';
import 'package:lm_feed_ui_example/utils/local_preference/user_local_preference.dart';
import 'package:lm_feed_ui_example/views/post_detail/post_detail/comment/add_comment/add_comment_bloc.dart';
import 'package:lm_feed_ui_example/views/post_detail/post_detail/comment/add_comment_reply/add_comment_reply_bloc.dart';
import 'package:lm_feed_ui_example/views/post_detail/post_detail/comment/all_comments/all_comments_bloc.dart';
import 'package:overlay_support/overlay_support.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final AllCommentsBloc _allCommentsBloc;
  late final AddCommentBloc _addCommentBloc;
  late final AddCommentReplyBloc _addCommentReplyBloc;
  final FocusNode focusNode = FocusNode();
  TextEditingController? _commentController;
  ValueNotifier<bool> rebuildButton = ValueNotifier(false);
  ValueNotifier<bool> rebuildPostWidget = ValueNotifier(false);
  ValueNotifier<bool> rebuildReplyWidget = ValueNotifier(false);
  final PagingController<int, Reply> _pagingController =
      PagingController(firstPageKey: 1);
  Post? postData;
  User currentUser = UserLocalPreference.instance.fetchUserData();

  List<UserTag> userTags = [];
  String? result = '';
  bool isEditing = false;
  bool isReplying = false;

  String? selectedCommentId;
  String? selectedUsername;
  String? selectedReplyId;

  @override
  void dispose() {
    _allCommentsBloc.close();
    _addCommentBloc.close();
    _addCommentReplyBloc.close();
    _pagingController.dispose();
    _commentController?.dispose();
    focusNode.dispose();
    rebuildButton.dispose();
    rebuildPostWidget.dispose();
    rebuildReplyWidget.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    updatePostDetails(context);
    _commentController = TextEditingController();
    if (_commentController != null) {
      _commentController!.addListener(
        () {
          if (_commentController!.text.isEmpty) {
            _commentController!.clear();
          }
        },
      );
    }
    _allCommentsBloc = AllCommentsBloc();
    _allCommentsBloc.add(GetAllComments(
        postDetailRequest: (PostDetailRequestBuilder()
              ..postId(widget.postId)
              ..page(1))
            .build(),
        forLoadMore: false));
    _addCommentBloc = AddCommentBloc();
    _addCommentReplyBloc = AddCommentReplyBloc();
    _addPaginationListener();
    if (focusNode.canRequestFocus) {
      focusNode.requestFocus();
    }
  }

  int _page = 1;

  void _addPaginationListener() {
    _pagingController.addPageRequestListener(
      (pageKey) {
        _allCommentsBloc.add(
          GetAllComments(
            postDetailRequest: (PostDetailRequestBuilder()
                  ..postId(widget.postId)
                  ..page(pageKey))
                .build(),
            forLoadMore: true,
          ),
        );
      },
    );
  }

  selectCommentToEdit(String commentId, String? replyId, String text) {
    selectedCommentId = commentId;
    isEditing = true;
    selectedReplyId = replyId;
    isReplying = false;
    // Map<String, dynamic> decodedComment =
    //     TaggingHelper.convertRouteToTagAndUserMap(text);
    // userTags = decodedComment['userTags'];
    // _commentController?.value = TextEditingValue(text: decodedComment['text']);
    openOnScreenKeyboard();
    rebuildReplyWidget.value = !rebuildReplyWidget.value;
  }

  deselectCommentToEdit() {
    selectedCommentId = null;
    selectedReplyId = null;
    isEditing = false;
    _commentController?.clear();
    closeOnScreenKeyboard();
    rebuildReplyWidget.value = !rebuildReplyWidget.value;
  }

  selectCommentToReply(String commentId, String username) {
    selectedCommentId = commentId;
    debugPrint(commentId);
    selectedUsername = username;
    isReplying = true;
    isEditing = false;
    openOnScreenKeyboard();
    rebuildReplyWidget.value = !rebuildReplyWidget.value;
  }

  deselectCommentToReply() {
    selectedCommentId = null;
    selectedUsername = null;
    isReplying = false;
    closeOnScreenKeyboard();
    _commentController?.clear();
    rebuildReplyWidget.value = !rebuildReplyWidget.value;
  }

  Future updatePostDetails(BuildContext context) async {
    final GetPostResponse postDetails =
        await locator<LikeMindsService>().getPost(
      (GetPostRequestBuilder()
            ..postId(widget.postId)
            ..page(1)
            ..pageSize(10))
          .build(),
    );
    if (postDetails.success) {
      postData = postDetails.post;
      rebuildPostWidget.value = !rebuildPostWidget.value;
    } else {
      toast(
        postDetails.errorMessage ?? 'An error occured',
        duration: Toast.LENGTH_LONG,
      );
    }
  }

  void increaseCommentCount() {
    postData!.commentCount = postData!.commentCount + 1;
  }

  void decreaseCommentCount() {
    if (postData!.commentCount != 0) {
      postData!.commentCount = postData!.commentCount - 1;
    }
  }

  void addCommentToList(AddCommentSuccess addCommentSuccess) {
    List<Reply>? commentItemList = _pagingController.itemList;
    commentItemList ??= [];
    if (commentItemList.length >= 10) {
      commentItemList.removeAt(9);
    }

    commentItemList.insert(0, addCommentSuccess.addCommentResponse.reply!);
    increaseCommentCount();
    rebuildPostWidget.value = !rebuildPostWidget.value;
  }

  void updateCommentInList(EditCommentSuccess editCommentSuccess) {
    List<Reply>? commentItemList = _pagingController.itemList;
    commentItemList ??= [];
    int index = commentItemList.indexWhere((element) =>
        element.id == editCommentSuccess.editCommentResponse.reply!.id);
    commentItemList[index] = editCommentSuccess.editCommentResponse.reply!;
    rebuildPostWidget.value = !rebuildPostWidget.value;
  }

  addReplyToList(AddCommentReplySuccess addCommentReplySuccess) {
    List<Reply>? commentItemList = _pagingController.itemList;
    if (addCommentReplySuccess.addCommentResponse.reply!.parentComment !=
        null) {
      int index = commentItemList!.indexWhere((element) =>
          element.id ==
          addCommentReplySuccess.addCommentResponse.reply!.parentComment!.id);
      if (index != -1) {
        commentItemList[index].repliesCount =
            commentItemList[index].repliesCount + 1;
        rebuildPostWidget.value = !rebuildPostWidget.value;
      }
    }
  }

  void removeCommentFromList(String commentId) {
    List<Reply>? commentItemList = _pagingController.itemList;
    int index =
        commentItemList!.indexWhere((element) => element.id == commentId);
    if (index != -1) {
      commentItemList.removeAt(index);
      decreaseCommentCount();
      rebuildPostWidget.value = !rebuildPostWidget.value;
    }
  }

  bool checkCommentRights() {
    final MemberStateResponse memberStateResponse =
        UserLocalPreference.instance.fetchMemberRights();
    if (memberStateResponse.state == 1) {
      return true;
    }
    bool memberRights = UserLocalPreference.instance.fetchMemberRight(10);
    return memberRights;
  }

  @override
  Widget build(BuildContext context) {
    // final right = checkCommentRights();
    return WillPopScope(
      onWillPop: () {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }

        return Future(() => false);
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AllCommentsBloc>(
            create: (context) => _allCommentsBloc,
          ),
          BlocProvider<AddCommentBloc>(
            create: (context) => _addCommentBloc,
          ),
          BlocProvider<AddCommentReplyBloc>(
            create: (context) => _addCommentReplyBloc,
          ),
        ],
        child: Scaffold(
            resizeToAvoidBottomInset: true,
            bottomSheet: SafeArea(
              child: BlocConsumer<AddCommentReplyBloc, AddCommentReplyState>(
                bloc: _addCommentReplyBloc,
                listener: (context, state) {
                  if (state is CommentDeleted) {
                    removeCommentFromList(state.commentId);
                  }
                  if (state is EditReplyLoading) {
                    deselectCommentToEdit();
                  }
                  if (state is ReplyEditingStarted) {
                    selectCommentToEdit(
                        state.commentId, state.replyId, state.text);
                  }
                  if (state is EditCommentLoading) {
                    deselectCommentToEdit();
                  }
                  if (state is CommentEditingStarted) {
                    selectCommentToEdit(state.commentId, null, state.text);
                  }
                  if (state is AddCommentReplySuccess) {
                    _commentController!.clear();
                    addReplyToList(state);
                    deselectCommentToReply();
                  }
                  if (state is AddCommentReplyError) {
                    deselectCommentToReply();
                  }
                  if (state is EditCommentSuccess) {
                    updateCommentInList(state);
                  }
                  if (state is EditReplySuccess) {}
                },
                builder: (context, state) => Container(
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      kVerticalPaddingMedium,
                      ValueListenableBuilder(
                          valueListenable: rebuildReplyWidget,
                          builder: (context, _, __) {
                            return isEditing || isReplying
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        LMTextView(
                                          text: isEditing
                                              ? "Editing ${selectedReplyId != null ? 'reply' : 'comment'}"
                                              : "Replying to",
                                          textStyle: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: kHeadingColor),
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        isEditing
                                            ? const SizedBox()
                                            : LMTextView(
                                                text: selectedUsername!,
                                                textStyle: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: kPrimaryColor),
                                              ),
                                        const Spacer(),
                                        LMIconButton(
                                          onTap: (active) {
                                            if (isEditing) {
                                              if (selectedReplyId != null) {
                                                _addCommentReplyBloc
                                                    .add(EditReplyCancel());
                                              } else {
                                                _addCommentReplyBloc
                                                    .add(EditCommentCancel());
                                              }
                                              deselectCommentToEdit();
                                            } else {
                                              deselectCommentToReply();
                                            }
                                          },
                                          icon: const LMIcon(
                                            type: LMIconType.icon,
                                            icon: Icons.close,
                                            color: kGreyColor,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox();
                          }),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: LMTextInput(
                          // profilePicture: LMProfilePicture(
                          //   fallbackText: currentUser.name,
                          //   imageUrl: currentUser.imageUrl,
                          //   size: 42,
                          // ),
                          sendButton: LMIconButton(
                            icon: LMIcon(
                              type: LMIconType.icon,
                              icon: Icons.send,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                            containerSize: 42,
                            backgroundColor: Theme.of(context).primaryColor,
                            borderRadius: 21,
                            onTap: (active) {},
                          ),
                        ),
                      ),
                      kVerticalPaddingLarge,
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: kBackgroundColor,
            appBar: AppBar(
              leading: LMIconButton(
                icon: const LMIcon(
                  type: LMIconType.icon,
                  icon: Icons.arrow_back_ios,
                  color: kHeadingColor,
                  size: 28,
                ),
                onTap: (active) {
                  Navigator.pop(context);
                },
                containerSize: 48,
              ),
              centerTitle: false,
              title: ValueListenableBuilder(
                valueListenable: rebuildPostWidget,
                builder: (context, _, __) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Post',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: kHeadingColor),
                      ),
                      Text(
                        ' ${postData == null ? '--' : postData!.commentCount} ${postData == null ? 'Comment' : postData!.commentCount > 1 ? 'Comments' : 'Comment'}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kHeadingColor),
                      ),
                    ],
                  );
                },
              ),
              elevation: 2,
            ),
            body: BlocConsumer<AllCommentsBloc, AllCommentsState>(
              listener: (context, state) {
                if (state is AllCommentsLoaded) {
                  _page++;
                  if (state.postDetails.postReplies!.replies.length < 10) {
                    _pagingController
                        .appendLastPage(state.postDetails.postReplies!.replies);
                  } else {
                    _pagingController.appendPage(
                        state.postDetails.postReplies!.replies, _page);
                  }
                }
              },
              bloc: _allCommentsBloc,
              builder: (context, state) {
                if (state is AllCommentsLoaded ||
                    state is PaginatedAllCommentsLoading) {
                  late PostDetailResponse postDetailResponse;
                  if (state is AllCommentsLoaded) {
                    debugPrint("AllCommentsLoaded$state");
                    postDetailResponse = state.postDetails;
                    postDetailResponse.users!.putIfAbsent(
                        currentUser.userUniqueId, () => currentUser);
                  } else {
                    debugPrint("PaginatedAllCommentsLoading$state");
                    postDetailResponse =
                        (state as PaginatedAllCommentsLoading).prevPostDetails;
                    postDetailResponse.users!.putIfAbsent(
                        currentUser.userUniqueId, () => currentUser);
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      await updatePostDetails(context);
                      _pagingController.refresh();
                      _page = 1;
                    },
                    child: Container(
                      color: kWhiteColor,
                      child: ValueListenableBuilder(
                          valueListenable: rebuildPostWidget,
                          builder: (context, _, __) {
                            return CustomScrollView(
                              slivers: [
                                const SliverPadding(
                                    padding: EdgeInsets.only(top: 16)),
                                SliverToBoxAdapter(
                                  child: postData == null
                                      ? const LMPostMediaShimmer()
                                      : LMPostWidget(
                                          post: postData!,
                                          onTagTap: (String userId) {
                                            locator<LikeMindsService>()
                                                .routeToProfile(userId);
                                          },
                                          isFeed: false,
                                          user: postDetailResponse.users![
                                              postDetailResponse
                                                  .postReplies!.userId]!,
                                          onTap: () {},
                                        ),
                                ),
                                const SliverPadding(
                                    padding: EdgeInsets.only(bottom: 12)),
                                SliverToBoxAdapter(
                                    child: postData == null
                                        ? const SizedBox.shrink()
                                        : postData!.commentCount >= 1
                                            ? Container(
                                                color: kWhiteColor,
                                                padding: const EdgeInsets.only(
                                                    left: 15, top: 15),
                                                child: Text(
                                                  '${postData!.commentCount} ${postData!.commentCount > 1 ? 'Comments' : 'Comment'}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              )
                                            : const SizedBox.shrink()),
                                PagedSliverList(
                                  pagingController: _pagingController,
                                  builderDelegate:
                                      PagedChildBuilderDelegate<Reply>(
                                    noMoreItemsIndicatorBuilder: (context) =>
                                        const SizedBox(height: 75),
                                    noItemsFoundIndicatorBuilder: (context) =>
                                        const Column(
                                      children: <Widget>[
                                        SizedBox(height: 42),
                                        Text(
                                          'No comment found',
                                          style: TextStyle(
                                            fontSize: kFontMedium,
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Be the first one to comment',
                                          style: TextStyle(
                                            fontSize: kFontSmall,
                                          ),
                                        ),
                                        SizedBox(height: 180),
                                      ],
                                    ),
                                    itemBuilder: (context, item, index) {
                                      return LMCommentTile(
                                        key: ValueKey(item.id),
                                        onTagTap: (String userId) {
                                          locator<LikeMindsService>()
                                              .routeToProfile(userId);
                                        },
                                        comment: item,
                                        user: postDetailResponse
                                            .users![item.userId]!,
                                        onMenuTap: (value) {},
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }),
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
                // if (state is AllCommentsLoading) {
                // }
              },
            )),
      ),
    );
  }

  void openOnScreenKeyboard() {
    if (focusNode.canRequestFocus) {
      focusNode.requestFocus();
      if (_commentController != null && _commentController!.text.isNotEmpty) {
        _commentController!.selection = TextSelection.fromPosition(
            TextPosition(offset: _commentController!.text.length));
      }
    }
  }

  void closeOnScreenKeyboard() {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }
}
