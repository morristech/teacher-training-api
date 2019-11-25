require 'spec_helper'
require 'fake_geocoder'

describe FakeGeocoder do
  let(:fake_geocoder) { FakeGeocoder.new }
  it 'allows for setting and retrieving geocoded values' do
    fake_geocoder.set_coordinates('search string', [12, 34])
    expect(fake_geocoder.read_coordinates('search string')).to eq [12, 34]
  end

  it 'raises when trying to retrieve a nonexistent value' do
    fake_geocoder.set_coordinates('search string', [12, 34])
    expect do
      fake_geocoder.read_coordinates('non existent')
    end.to raise_error(KeyError)
  end
end
