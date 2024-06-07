# frozen_string_literal: true

RSpec.describe "catalog/index.json", :api do
  let(:response) { instance_double(Blacklight::Solr::Response, documents: docs, prev_page: nil, next_page: 2, total_pages: 3) }
  let(:docs) do
    [
      SolrDocument.new(id: '123', title_tsim: 'Book1', author_tsim: 'Julie', format: 'Book'),
      SolrDocument.new(id: '456', title_tsim: 'Article1', author_tsim: 'Rosie', format: 'Article')
    ]
  end
  let(:config) do
    Blacklight::Configuration.new do |config|
      config.index.title_field = 'title_tsim'
      config.add_facet_field :format
    end
  end
  let(:presenter) { Blacklight::JsonPresenter.new(response, config) }

  let(:hash) do
    render template: "catalog/index", formats: [:json]
    JSON.parse(rendered).with_indifferent_access
  end

  let(:book_facet_item) do
    Blacklight::Solr::Response::Facets::FacetItem.new('value' => 'Book', 'hits' => 30, 'label' => 'Book')
  end

  let(:format_facet) do
    Blacklight::Solr::Response::Facets::FacetField.new('format',
                                                       [book_facet_item],
                                                       'label' => 'Format')
  end

  before do
    allow(view).to receive_messages(blacklight_config: config, search_action_path: 'http://test.host/some/search/url', search_facet_path: 'http://test.host/some/facet/url')
    allow(presenter).to receive_messages(pagination_info: { current_page: 1,
                                                            next_page: 2,
                                                            prev_page: nil }, search_facets: [format_facet])
    assign :presenter, presenter
    assign :response, response
  end

  it "has pagination links" do
    expect(hash).to include(links: hash_including(
      self: 'http://test.host/',
      next: 'http://test.host/?page=2',
      last: 'http://test.host/?page=3'
    ))
  end

  it "has pagination information" do
    expect(hash).to include(meta: hash_including(pages:
      {
        'current_page' => 1,
        'next_page' => 2,
        'prev_page' => nil
      }))
  end

  it "includes documents, links, and their attributes" do
    expect(hash).to include(data: [
                              {
                                id: '123',
                                type: 'Book',
                                attributes: {
                                  title: 'Book1'
                                },
                                links: { self: 'http://test.host/catalog/123' }
                              },
                              {
                                id: '456',
                                type: 'Article',
                                attributes: {
                                  title: 'Article1'
                                },
                                links: { self: 'http://test.host/catalog/456' }
                              }
                            ])
  end

  describe 'facets' do
    let(:facets) { hash[:included].select { |x| x['type'] == 'facet' } }
    let(:format) { facets.find { |x| x['id'] == 'format' } }
    let(:format_items) { format['attributes']['items'] }
    let(:format_item_attributes) { format_items.pluck('attributes') }

    context 'when no facets have been selected' do
      it 'has facet information and links' do
        expect(facets).to be_present
        expect(facets.pluck('id')).to include 'format'
        expect(format['links']).to include self: 'http://test.host/some/facet/url'
        expect(format['attributes']['label']).to eq 'Format'
        expect(format_item_attributes).to contain_exactly({ value: 'Book', hits: 30, label: 'Book' })
      end
    end

    context 'when facets have been selected' do
      before do
        params[:f] = { format: ['Book'] }
      end

      it 'has a link to remove the selected value' do
        expect(format_items.first['links']).to eq('remove' => 'http://test.host/some/search/url')
      end
    end
  end
end
