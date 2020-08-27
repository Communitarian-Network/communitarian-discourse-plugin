export default function () {
  this.route(
    "verificationIntentsShow",
    { path: "/communitarian/verification_intents/:id" }
  );

  this.route(
    "categoryDialogs",
    { path: "/c/*category_slug_path_with_id/l/dialogs" }
  );
}
