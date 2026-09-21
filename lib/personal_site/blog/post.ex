defmodule PersonalSite.Blog.Post do
  @enforce_keys [:slug, :title, :date, :description, :body]
  defstruct @enforce_keys

  def build(path, %{title: title, date: %Date{}, description: description} = attrs, body)
      when is_binary(title) and is_binary(description) do
    struct!(__MODULE__, Map.merge(attrs, %{slug: Path.basename(path, ".md"), body: body}))
  end
end
