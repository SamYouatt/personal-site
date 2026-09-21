defmodule PersonalSite.BlogTest do
  use ExUnit.Case, async: true

  alias PersonalSite.Blog

  test "legacy section anchors remain alongside generated heading IDs" do
    for {slug, legacy, current} <- [
          {"site-design", "zola-senorita", "zola-señorita"},
          {"a-classy-refactoring", "a-kotlin-mascot-in-crab-s-clothing",
           "a-kotlin-mascot-in-crabs-clothing"}
        ] do
      document = Blog.get_post(slug).body |> LazyHTML.from_fragment()

      assert document
             |> LazyHTML.query("div[id='#{legacy}'] + h2, div[id='#{legacy}'] + h3")
             |> Enum.count() == 1

      assert document
             |> LazyHTML.query("h2[id='#{current}'], h3[id='#{current}']")
             |> Enum.count() == 1
    end
  end

  test "all 58 code blocks are highlighted, including the four migrated SCSS examples" do
    documents = Enum.map(Blog.all_posts(), &LazyHTML.from_fragment(&1.body))
    assert Enum.sum(Enum.map(documents, &(LazyHTML.query(&1, "pre.lumis") |> Enum.count()))) == 58

    for document <- documents, block <- LazyHTML.query(document, "pre.lumis") do
      assert block |> LazyHTML.query("span[style]") |> Enum.count() > 0
    end

    design = Blog.get_post("site-design").body |> LazyHTML.from_fragment()
    assert design |> LazyHTML.query("code.language-scss") |> Enum.count() == 4
  end

  test "only the specified line is emphasized in each annotated code block" do
    for {slug, line, expected_text} <- [
          {"particles", "12", ".insert(Particle(element))"},
          {"site-design", "3", "data-slug"}
        ] do
      document = Blog.get_post(slug).body |> LazyHTML.from_fragment()
      highlighted = LazyHTML.query(document, ".l-line.highlighted")
      assert LazyHTML.attribute(highlighted, "data-line") == [line]
      assert LazyHTML.text(highlighted) =~ expected_text
    end
  end

  test "content remains Markdown and literal code, not executable templates" do
    design = Blog.get_post("site-design").body |> LazyHTML.from_fragment()
    assert design |> LazyHTML.query("pre code") |> LazyHTML.text() =~ "{{slug}}"
    assert design |> LazyHTML.query("pre code") |> LazyHTML.text() =~ "<script"
    assert design |> LazyHTML.query("script") |> Enum.count() == 0
    assert design |> LazyHTML.query("a[href='https://www.polaroid.com']") |> Enum.count() == 1

    calendar = Blog.get_post("so-calendar-1").body |> LazyHTML.from_fragment()
    assert calendar |> LazyHTML.query("del") |> Enum.count() == 1
  end

  test "CodePen embeds are titled, lazy-loaded and have fallback links" do
    design = Blog.get_post("site-design").body |> LazyHTML.from_fragment()
    frames = LazyHTML.query(design, "iframe[title][loading=lazy][height='400']")

    assert LazyHTML.attribute(frames, "src") == [
             "https://codepen.io/sam-youatt/embed/OJjKEGa?default-tab=css%2Cresult&editable=true",
             "https://codepen.io/sam-youatt/embed/XWerqxx?default-tab=css%2Cresult&editable=true"
           ]

    assert design
           |> LazyHTML.query("a[href^='https://codepen.io/sam-youatt/pen/']")
           |> Enum.count() == 2
  end

  test "invalid metadata fails rather than publishing an incomplete post" do
    for attrs <- [
          %{title: "Test", date: "2026-01-01", description: "Test"},
          %{title: "Test", date: ~D[2026-01-01]}
        ] do
      assert_raise FunctionClauseError, fn -> Blog.Post.build("invalid.md", attrs, "body") end
    end
  end
end
