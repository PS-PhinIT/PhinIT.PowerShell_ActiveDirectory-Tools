from __future__ import annotations

from dataclasses import dataclass
from html import escape
from pathlib import Path
import re
from urllib.parse import quote

from markupsafe import Markup

try:
    import markdown as markdown_library
except ImportError:  # pragma: no cover - fallback for incomplete local environments
    markdown_library = None


class DocumentationNotFoundError(FileNotFoundError):
    """Raised when a requested documentation file cannot be resolved safely."""


@dataclass(frozen=True)
class DocumentationItem:
    title: str
    relative_path: str
    excerpt: str
    folder_path: str
    href: str
    search_rank: int


def build_documentation_href(*, doc: str | None = None, section: str | None = None, search_query: str | None = None) -> str:
    params: list[tuple[str, str]] = []
    if doc:
        params.append(("doc", doc))
    if section:
        params.append(("section", section))
    if search_query:
        params.append(("q", search_query))

    if not params:
        return "/documentation"

    query = "&".join(f"{key}={quote(value, safe='/')}" for key, value in params)
    return f"/documentation?{query}"


def _humanize_name(value: str) -> str:
    cleaned = re.sub(r"^[0-9]+[_-]*", "", value)
    cleaned = re.sub(r"^[A-Z][_-]", "", cleaned)
    cleaned = cleaned.replace("_", " ").replace("-", " ").strip()
    return cleaned or value


def _extract_title_and_excerpt(content: str, fallback_title: str) -> tuple[str, str]:
    title = fallback_title
    excerpt = "Noch keine Kurzbeschreibung vorhanden."

    for raw_line in content.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            title = line.lstrip("#").strip() or fallback_title
            continue
        if line.startswith("<!--"):
            continue
        excerpt = line
        break

    return title, excerpt


def _normalize_search_query(search_query: str | None) -> str | None:
    if search_query is None:
        return None

    normalized = search_query.strip()
    return normalized or None


def _matches_search_query(search_query: str | None, *parts: str) -> bool:
    normalized = _normalize_search_query(search_query)
    if normalized is None:
        return True

    haystack = "\n".join(part.casefold() for part in parts if part)
    terms = [term for term in re.split(r"\s+", normalized.casefold()) if term]
    return all(term in haystack for term in terms)


def _calculate_search_rank(search_query: str | None, *, title: str, excerpt: str, relative_path: str, folder_path: str, content: str) -> int:
    normalized = _normalize_search_query(search_query)
    if normalized is None:
        return 0

    title_value = title.casefold()
    excerpt_value = excerpt.casefold()
    path_value = relative_path.casefold()
    folder_value = folder_path.casefold()
    content_value = content.casefold()
    terms = [term for term in re.split(r"\s+", normalized.casefold()) if term]

    rank = 0
    for term in terms:
        if term in title_value:
            rank += 12
        if term in excerpt_value:
            rank += 8
        if term in path_value:
            rank += 6
        if term in folder_value:
            rank += 4
        if term in content_value:
            rank += 2

    return rank


def _read_markdown_file(file_path: Path) -> str:
    return file_path.read_text(encoding="utf-8")


def list_documentation_sections(docs_dir: Path, search_query: str | None = None) -> tuple[list[dict[str, object]], list[DocumentationItem]]:
    if not docs_dir.exists():
        return [], []

    grouped: dict[str, list[DocumentationItem]] = {}
    all_documents: list[DocumentationItem] = []
    normalized_query = _normalize_search_query(search_query)

    for file_path in sorted(docs_dir.rglob("*.md")):
        if not file_path.is_file():
            continue

        relative_path = file_path.relative_to(docs_dir).as_posix()
        folder_key = file_path.parent.relative_to(docs_dir).as_posix()
        content = _read_markdown_file(file_path)
        title, excerpt = _extract_title_and_excerpt(content, _humanize_name(file_path.stem))

        if not _matches_search_query(normalized_query, title, excerpt, relative_path, folder_key, content):
            continue

        search_rank = _calculate_search_rank(
            normalized_query,
            title=title,
            excerpt=excerpt,
            relative_path=relative_path,
            folder_path=folder_key,
            content=content,
        )

        item = DocumentationItem(
            title=title,
            relative_path=relative_path,
            excerpt=excerpt,
            folder_path=folder_key,
            href=build_documentation_href(doc=relative_path, search_query=normalized_query),
            search_rank=search_rank,
        )
        grouped.setdefault(folder_key, []).append(item)
        all_documents.append(item)

    if normalized_query:
        for folder_key, items in grouped.items():
            grouped[folder_key] = sorted(items, key=lambda item: (-item.search_rank, item.title, item.relative_path))
        all_documents = sorted(all_documents, key=lambda item: (-item.search_rank, item.title, item.relative_path))

    sections: list[dict[str, object]] = []
    for folder_key in sorted(grouped):
        folder_name = folder_key.split("/")[-1] if folder_key else "ROOT"
        sections.append(
            {
                "folder_path": folder_key,
                "folder_title": _humanize_name(folder_name),
                "document_count": len(grouped[folder_key]),
                "index_href": build_documentation_href(section=folder_key, search_query=normalized_query),
                "documents": grouped[folder_key],
            }
        )

    return sections, all_documents


def _build_section_index_markdown(section: dict[str, object], *, search_query: str | None = None) -> str:
    folder_title = str(section["folder_title"])
    folder_path = str(section["folder_path"])
    documents = list(section["documents"])
    document_count = int(section["document_count"])

    lines = [
        f"# {folder_title} – Auto-Index",
        "",
        "Automatisch generiertes Bereichsverzeichnis für diesen `/DOC`-Unterordner.",
        "",
        f"- Ordnerpfad: `{folder_path}`",
        f"- Enthaltene Dokumente: **{document_count}**",
    ]

    normalized_query = _normalize_search_query(search_query)
    if normalized_query:
        lines.extend(["", f"> Aktiver Filter: `{normalized_query}`"])

    lines.extend(["", "## Enthaltene Dokumente", ""])

    for document in documents:
        lines.extend(
            [
                f"### [{document.title}]({document.href})",
                "",
                document.excerpt,
                "",
                f"- Datei: `{document.relative_path}`",
                "",
            ]
        )

    return "\n".join(lines).strip()


def resolve_document_path(docs_dir: Path, relative_path: str) -> Path:
    candidate = (docs_dir / relative_path).resolve()
    docs_root = docs_dir.resolve()

    if docs_root not in candidate.parents and candidate != docs_root:
        raise DocumentationNotFoundError("Angeforderte Dokumentation liegt außerhalb des DOC-Verzeichnisses.")
    if candidate.suffix.lower() != ".md" or not candidate.is_file():
        raise DocumentationNotFoundError("Angeforderte Dokumentation wurde nicht gefunden.")

    return candidate


def render_markdown(content: str) -> Markup:
    if markdown_library is None:
        return Markup(f"<pre>{escape(content)}</pre>")

    rendered = markdown_library.markdown(
        escape(content, quote=False),
        extensions=["extra", "toc"],
        output_format="html5",
    )
    return Markup(rendered)


def build_documentation_view(
    docs_dir: Path,
    selected_relative_path: str | None,
    *,
    selected_section_path: str | None = None,
    search_query: str | None = None,
    preview_markdown: str | None = None,
) -> dict[str, object]:
    normalized_query = _normalize_search_query(search_query)
    all_sections, all_documents = list_documentation_sections(docs_dir)
    filtered_sections, filtered_documents = list_documentation_sections(docs_dir, normalized_query)

    section_lookup = {str(section["folder_path"]): section for section in all_sections}
    filtered_section_lookup = {str(section["folder_path"]): section for section in filtered_sections}
    document_lookup = {item.relative_path: item for item in all_documents}

    sections = filtered_sections if normalized_query else all_sections
    documents = filtered_documents if normalized_query else all_documents

    selected_item: DocumentationItem | None = None
    selected_section: dict[str, object] | None = None
    selected_relative = selected_relative_path
    if selected_relative:
        selected_item = document_lookup.get(selected_relative)
        if selected_item is None:
            raise DocumentationNotFoundError("Die angeforderte Markdown-Datei ist nicht im live verfügbaren DOC-Baum vorhanden.")
    elif selected_section_path:
        selected_section = filtered_section_lookup.get(selected_section_path) or section_lookup.get(selected_section_path)
        if selected_section is None:
            raise DocumentationNotFoundError("Der angeforderte Dokumentationsabschnitt ist nicht im live verfügbaren DOC-Baum vorhanden.")
    elif documents:
        selected_item = documents[0]
        selected_relative = selected_item.relative_path

    selected_markdown = ""
    selected_html = Markup("<p>Keine Dokumentation gefunden.</p>")
    selected_meta: dict[str, object] | None = None
    if selected_item is not None and selected_relative is not None:
        file_path = resolve_document_path(docs_dir, selected_relative)
        selected_markdown = _read_markdown_file(file_path)
        selected_html = render_markdown(selected_markdown)
        selected_meta = {
            "title": selected_item.title,
            "relative_path": selected_item.relative_path,
            "updated_at": file_path.stat().st_mtime,
        }
    elif selected_section is not None:
        selected_markdown = _build_section_index_markdown(selected_section, search_query=normalized_query)
        selected_html = render_markdown(selected_markdown)
        selected_meta = {
            "title": f"{selected_section['folder_title']} – Auto-Index",
            "relative_path": selected_section["folder_path"],
            "updated_at": None,
        }

    preview_source = selected_markdown if preview_markdown is None else preview_markdown
    preview_has_content = bool(preview_source.strip())
    preview_html = render_markdown(preview_source if preview_has_content else "_Noch kein Markdown für die Vorschau vorhanden._")

    selected_section_path_value = selected_section_path
    if selected_item is not None:
        selected_section_path_value = selected_item.folder_path
    elif selected_section is not None:
        selected_section_path_value = str(selected_section["folder_path"])

    return {
        "doc_sections": sections,
        "doc_count": len(documents),
        "folder_count": len(sections),
        "total_doc_count": len(all_documents),
        "total_folder_count": len(all_sections),
        "search_query": normalized_query or "",
        "search_active": normalized_query is not None,
        "selected_doc": selected_item,
        "selected_section": selected_section,
        "selected_section_path": selected_section_path_value,
        "selected_doc_relative_path": selected_relative,
        "selected_doc_markdown": selected_markdown,
        "selected_doc_html": selected_html,
        "selected_doc_meta": selected_meta,
        "preview_source_markdown": preview_source,
        "preview_html": preview_html,
        "preview_has_content": preview_has_content,
        "preview_source_length": len(preview_source),
    }